#!/bin/sh
# S44 to S48 of tests/incremental/SCENARIOS.md: MLton's compiler (606 files,
# in the order of its mlton/mlton-rune.txt) built in units through a cache,
# cold and warm, then edited as each scenario says, each build timed and its
# units compiled counted (--explain-rebuild); at the end the last warm build
# against a build without the cache, which must be the same bytes. Not in
# make check: a cold build takes minutes and gigabytes.
#   tests/incremental/mlton.sh MLTON-CHECKOUT [OUT]
# MLTON-CHECKOUT is MLton at 5fe943391 (MLton PR #660), whose mlton/ has
# mlton-rune.txt. Wants 20 GB of memory available.
set -u
cd "$(dirname "$0")/../.."
root=$(pwd)
src=${1:?usage: tests/incremental/mlton.sh MLTON-CHECKOUT [OUT]}
out=${2:-$root/tests/out/mlton}
list=$src/mlton/mlton-rune.txt
[ -f "$list" ] || { echo "mlton.sh: no $list" >&2; exit 2; }
if [ "$(free -g | awk '/^Mem:/ { print $7 }')" -lt 20 ]; then
  echo "mlton.sh: less than 20 GB available" >&2; exit 2
fi
rm -rf "$out"
mkdir -p "$out/work/mlton"
work=$out/work
while read -r f; do
  mkdir -p "$work/mlton/$(dirname "$f")"
  cp "$src/mlton/$f" "$work/mlton/$f"
done < "$list"
cp "$list" "$work/mlton/files"
fails=0

# build NAME [FLAGS]: the compiler built through the cache, timed; $secs its
# wall time, $count the MLton units it compiled
build() {
  name=$1; shift
  t0=$(date +%s.%N)
  # shellcheck disable=SC2046
  (cd "$work/mlton" && ulimit -v 12582912 &&
   "$root/bin/runevm" --heap-size 67108864 --heap-limit 5368709120 "$root/bin/rune.rbc" --lib "$root/lib" \
     --units --type-work=1000000000 "$@" $(cat files) -o "$out/$name.rbc") > "$out/$name.out" 2> "$out/$name.err"
  status=$?
  secs=$(echo "$(date +%s.%N) - $t0" | bc)
  count=$(grep '^rune: compiled ' "$out/$name.err" | grep -vc 'lib/basis/')
  printf '| %s | %s | %.1f | %s |\n' "$name" "$status" "$secs" "$count" | tee -a "$out/mlton.md"
  [ "$status" = 0 ] || fails=$((fails + 1))
}
cached() { build "$@" --cache-dir "$work/cache" --explain-rebuild; }
# insert FILE PATTERN TEXT: TEXT as a line after the first line matching PATTERN
insert() {
  awk -v p="$2" -v t="$3" '{ print } !done && $0 ~ p { print t; done = 1 }' "$work/mlton/$1" > "$work/mlton/$1.new" &&
    mv "$work/mlton/$1.new" "$work/mlton/$1"
}

echo "| Build | Status | Wall s | MLton units compiled |" | tee "$out/mlton.md"
echo "|---|---|---:|---:|" | tee -a "$out/mlton.md"
# S44, cold and warm
cached S44-cold
cached S44-warm
# S45, a leaf: main/main.sml, which nothing uses, given a declaration of no name
printf 'val _ = ()\n' >> "$work/mlton/main/main.sml"
cached S45-leaf
# S46, a root: the body of Control (control/control.sml), sealed by CONTROL
insert control/control.sml '^structure Control: CONTROL =$' 'struct val _ = ()'
sed -i '/^struct val _ = ()$/{n;/^struct$/d}' "$work/mlton/control/control.sml"
cached S46-root
# S47, a used interface: a value added to CONTROL_FLAGS and ControlFlags
insert control/control-flags.sig '^signature CONTROL_FLAGS =$' '   sig val runeScenarioS47: int'
sed -i '/^   sig val runeScenarioS47: int$/{n;/^   sig$/d}' "$work/mlton/control/control-flags.sig"
insert control/control-flags.sml '^structure ControlFlags: CONTROL_FLAGS =$' 'struct val runeScenarioS47 = 0'
sed -i '/^struct val runeScenarioS47 = 0$/{n;/^struct$/d}' "$work/mlton/control/control-flags.sml"
cached S47-interface
# S48, a functor body: Profile (ssa/profile.fun), applied in eight files
insert ssa/profile.fun '^functor Profile ' 'struct val _ = ()'
sed -i '/^struct val _ = ()$/{n;/^struct$/d}' "$work/mlton/ssa/profile.fun"
cached S48-functor
# the last warm build against one without the cache
build nocache --no-cache
if cmp -s "$out/S48-functor.rbc" "$out/nocache.rbc"; then echo "mlton: the last warm build is the bytes of a build without the cache"
else echo "FAIL mlton: the last warm build differs from a build without the cache"; fails=$((fails + 1)); fi
echo "mlton: table in $out/mlton.md, $fails failures"
[ $fails = 0 ]
