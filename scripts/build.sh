#!/bin/sh
set -eu
host=$1
root=$(pwd -P)
. "$root/scripts/tools.sh"
case "$host" in
    smlnj) runtime=$(find_sml); builder=$(command -v "${ML_BUILD:-ml-build}") ;;
    polyml) runtime=$(command -v "${POLY:-poly}"); builder=$runtime ;;
    mlton) runtime=$(command -v "${MLTON:-mlton}"); builder=$runtime ;;
    mosml)
        mosml_paths=$(sh "$root/scripts/build_mosml.sh")
        runtime=$(printf '%s\n' "$mosml_paths" | sed -n '1p')
        builder=$(printf '%s\n' "$mosml_paths" | sed -n '2p')
        linker=$(printf '%s\n' "$mosml_paths" | sed -n '3p')
        stdlib=$(printf '%s\n' "$mosml_paths" | sed -n '4p')
        intinf="$stdlib"
        ;;
    *) echo "Unknown HOST: $host (use smlnj, polyml, mlton, or mosml)" >&2; exit 1 ;;
esac
# Resolve relative tool overrides before changing directories.
case "$runtime" in /*) ;; *) runtime="$root/$runtime" ;; esac
case "$builder" in /*) ;; *) builder="$root/$builder" ;; esac
case "${linker:-}" in /*|"") ;; *) linker="$root/$linker" ;; esac
dest="$root/build/$host"
mkdir -p "$dest/src"
{
    printf '%s\n' "$runtime" "$builder"
    cksum sources.list scripts/build.sh scripts/tools.sh host/*.sml
    test "$host" != mosml || cksum scripts/build_mosml.sh
    while IFS= read -r source; do cksum "$source"; done < sources.list
} > "$dest/fingerprint.new"
if [ -x "$dest/rune" ] && [ -f "$dest/fingerprint" ] && cmp -s "$dest/fingerprint.new" "$dest/fingerprint"; then
    rm "$dest/fingerprint.new"
    exit 0
fi
while IFS= read -r source; do cp "$source" "$dest/$source"; done < sources.list
cp sources.list "$dest/sources.list"
cp host/mlton.sml "$dest/main-mlton.sml"
cp host/polyml.sml "$dest/run-polyml.sml"
cp host/smlnj.sml "$dest/main-smlnj.sml"
cp host/mosml.sml "$dest/main-mosml.sml"
printf '%s\n' "$runtime" > "$dest/runtime"
cd "$dest"
case "$host" in
    mlton)
        { printf '%s\n' '$(SML_LIB)/basis/basis.mlb'; cat sources.list; printf '%s\n' main-mlton.sml; } > rune.mlb
        "$builder" -output rune.new rune.mlb
        mv rune.new rune
        ;;
    polyml)
        { while IFS= read -r source; do printf 'use "%s";\n' "$source"; done < sources.list
          printf '%s\n' 'PolyML.SaveState.saveState "rune.state.new";'
          printf '%s\n' 'val () = OS.Process.terminate OS.Process.success;'
        } > build-polyml.sml
        "$builder" --error-exit --script build-polyml.sml
        test -s rune.state.new
        mv rune.state.new rune.state
        cat > rune.new <<'SH'
#!/bin/sh
set -eu
rune_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
IFS= read -r runtime < "$rune_dir/runtime"
RUNE_POLY_STATE="$rune_dir/rune.state"
export RUNE_POLY_STATE
# Poly/ML scans even arguments after --script for its own options.
for arg in "$@"; do shift; set -- "$@" "rune:$arg"; done
exec "$runtime" --script "$rune_dir/run-polyml.sml" "$@"
SH
        chmod +x rune.new
        mv rune.new rune
        ;;
    smlnj)
        { printf '%s\n' 'Group is' '  $/basis.cm'; cat sources.list; printf '%s\n' main-smlnj.sml; } > sources.cm
        rm -f rune-image.*
        "$builder" sources.cm SMLNJMain.main rune-image
        found=no
        for image in rune-image.*; do if [ -s "$image" ]; then found=yes; fi; done
        test "$found" = yes
        cat > rune.new <<'SH'
#!/bin/sh
set -eu
rune_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
IFS= read -r runtime < "$rune_dir/runtime"
for arg in "$@"; do shift; set -- "$@" "rune:$arg"; done
exec "$runtime" "@SMLload=$rune_dir/rune-image" "$@"
SH
        chmod +x rune.new
        mv rune.new rune
        ;;
    mosml)
        : > sources.mosml
        while IFS= read -r source; do
            unit=$(basename "$source" .sml)
            first=$(printf '%s' "$unit" | cut -c1 | tr '[:lower:]' '[:upper:]')
            unit="$first$(printf '%s' "$unit" | cut -c2-)"
            mosml_source="$unit.sml"
            printf '%s\n' "$mosml_source" >> sources.mosml
            cp "$source" "$mosml_source.full"
            if grep -q '^signature ' "$mosml_source.full"; then
                signature=$(sed -n 's/^signature \([^ ]*\).*/\1/p' "$mosml_source.full")
                awk '/^structure / { body=1 } !body { print }' "$mosml_source.full" |
                    sed "s/^signature $signature/signature $unit/" > "$unit.sig"
                awk '/^structure / { body=1 } body { print }' "$mosml_source.full" |
                    sed "s/:> $signature/:> $unit/" > "$mosml_source"
                "$runtime" "$builder" -stdlib "$stdlib" -I "$intinf" -P none -conservative -structure "$unit.sig"
            else
                mv "$mosml_source.full" "$mosml_source"
            fi
            "$runtime" "$builder" -stdlib "$stdlib" -I "$intinf" -P none -conservative -structure "$mosml_source"
        done < sources.list
        cp main-mosml.sml Main-mosml.sml
        "$runtime" "$builder" -stdlib "$stdlib" -I "$intinf" -P none -conservative -toplevel Main-mosml.sml
        uos=$(while IFS= read -r source; do unit=$(basename "$source" .sml); first=$(printf '%s' "$unit" | cut -c1 | tr '[:lower:]' '[:upper:]'); printf '%s%s.uo ' "$first" "$(printf '%s' "$unit" | cut -c2-)"; done < sources.list)
        "$runtime" "$linker" -stdlib "$stdlib" -I "$intinf" -P none -o rune.new $uos Main-mosml.uo
        chmod +x rune.new
        mv rune.new rune.bin
        cat > rune.new <<'SH'
#!/bin/sh
set -eu
rune_dir=$(CDPATH= cd -P "$(dirname "$0")" && pwd)
set +e
"$rune_dir/rune.bin" "$@"
status=$?
set -e
test "$status" -eq 255 && status=1
exit "$status"
SH
        chmod +x rune.new
        mv rune.new rune
        ;;
esac
./rune --version
mv fingerprint.new fingerprint
