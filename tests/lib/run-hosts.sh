#!/bin/sh
# The libraries beside the basis library on the other compilers
# (docs/plans/quickcheck.md, D10 and M3): each library's tests, built by
# MLton, SML/NJ (64 and 32 bits), Poly/ML and MLKit against their own Basis
# Library, must give what they give on Rune.
#   tests/lib/run-hosts.sh [HOST...]      (default: every host `make hosts` installed)
# A library is plain Standard ML '97 and is never changed to work around a
# host's bug: a failure on a host is a line of tests/lib/deviations.txt
# (config | label | CATEGORY | reason, in the form of
# tests/basis/deviations.txt), with a report in docs/bugreport/HOST.
# `make test-lib-hosts` runs this; it is not part of `make check`, as the
# Basis suite's matrix is not.
set -u
cd "$(dirname "$0")/../.."
hosts_dir=${RUNE_HOSTS:-$HOME/.local/rune-hosts}
mlton=${MLTON:-$hosts_dir/mlton/bin/mlton}
smlnj=${SMLNJ:-$hosts_dir/smlnj/bin/sml}
smlnj32=${SMLNJ32:-$hosts_dir/smlnj32/bin/sml}
poly=${POLY:-$hosts_dir/polyml/bin/poly}
mlkit=${MLKIT:-$hosts_dir/mlkit/bin/mlkit}
mlkit_lib=${MLKIT_LIB:-$hosts_dir/mlkit/lib/mlkit}
out=tests/out/lib-hosts
rm -rf "$out"
mkdir -p "$out"
top=$(pwd)

hosts=${*:-mlton smlnj smlnj32 polyml mlkit}

# The tests: LABEL | the library's files | the test program | how its output
# is judged (kat: equal to the reference's output; props: no FAIL line).
cc=${CC:-cc}
"$cc" -O2 -o "$out/random-reference" tests/lib/random/reference.c && "$out/random-reference" > "$out/random-kat.expected" ||
  { echo "test-lib-hosts: tests/lib/random/reference.c does not build or run"; exit 1; }
random="lib/random/random_sig.sml lib/random/random.sml"
# the library's files that the other compilers build (host column yes); the
# rest name structures that the Basis leaves optional, or Rune's own
property=$(sed -n 's/^\([a-z_0-9]*\.sml\) *| *[a-z]* *| *yes *|.*/lib\/test\/property\/\1/p' lib/test/property/MANIFEST | tr '\n' ' ')
tests="random.kat|$random|tests/lib/random/kat.sml|kat
random.props|$random|tests/lib/random/props.sml|props
property.core|$random $property|tests/lib/property/core.sml|core
property.shrink|$random $property|tests/lib/property/shrink.sml|props"

passed=0
explained=0
failed=0

# deviation CONFIG LABEL: the reason tests/lib/deviations.txt gives, if any
deviation() {
  while IFS='|' read -r c l cat why; do
    c=$(echo $c); l=$(echo $l)
    case "$c" in ""|\#*) continue ;; esac
    # shellcheck disable=SC2254
    case "$1" in $c) ;; *) continue ;; esac
    # shellcheck disable=SC2254
    case "$2" in $l) echo "$(echo $cat): $(echo $why)"; return 0 ;; esac
  done < tests/lib/deviations.txt
  return 1
}

# build HOST NAME FILES...: the program of the files, built by the host,
# written to $out/NAME.out when it runs; a build error to $out/NAME.err
build() {
  host=$1; name=$2; shift 2
  case "$host" in
    mlton)
      { echo '$(SML_LIB)/basis/basis.mlb'; for f in "$@"; do echo "$top/$f"; done; } > "$out/$name.mlb"
      "$mlton" -output "$out/$name" "$out/$name.mlb" > "$out/$name.err" 2>&1 && "$out/$name" > "$out/$name.out" 2>&1 ;;
    smlnj|smlnj32)
      if [ "$host" = smlnj ]; then sml=$smlnj; else sml=$smlnj32; fi
      echo 'val () = OS.Process.exit OS.Process.success' > "$out/exit.sml"
      "$sml" "$@" "$out/exit.sml" < /dev/null > "$out/$name.raw" 2>&1
      grep -v -E '^(\[|Standard ML|val |- |structure |signature |type |datatype |exception |fun )' "$out/$name.raw" > "$out/$name.out"
      ! grep -q -E 'Error:|uncaught exception' "$out/$name.raw" ;;
    polyml)
      { for f in "$@"; do echo "use \"$f\";"; done; echo 'OS.Process.exit OS.Process.success;'; } > "$out/$name.use"
      "$poly" -q < "$out/$name.use" > "$out/$name.raw" 2>&1
      grep -v -E '^(val |structure |signature |type |datatype |exception |fun |> )' "$out/$name.raw" > "$out/$name.out"
      ! grep -q -E 'Error-|Exception-' "$out/$name.raw" ;;
    mlkit)
      { echo '$(SML_LIB)/basis/basis.mlb'; for f in "$@"; do echo "$top/$f"; done; } > "$out/$name.mlb"
      (cd "$out" && SML_LIB=$mlkit_lib "$mlkit" -o "$name" "$name.mlb" > "$name.err" 2>&1) && "$out/$name" > "$out/$name.out" 2>&1 ;;
  esac
}

for host in $hosts; do
  case "$host" in
    mlton) bin=$mlton ;; smlnj) bin=$smlnj ;; smlnj32) bin=$smlnj32 ;; polyml) bin=$poly ;; mlkit) bin=$mlkit ;;
    *) echo "unknown host: $host"; exit 2 ;;
  esac
  if [ ! -x "$bin" ]; then echo "$host: not installed ($bin; make hosts)"; continue; fi
  echo "$tests" | while IFS='|' read -r label files program judge; do
    name="$host-$label"
    # shellcheck disable=SC2086
    if build "$host" "$name" $files "$program"; then
      case "$judge" in
        kat) grep -E '^(seed|split|below)' "$out/$name.out" > "$out/$name.got"; cmp -s "$out/$name.got" "$out/random-kat.expected" ;;
        props) grep -q '^PASS' "$out/$name.out" && ! grep -q '^FAIL' "$out/$name.out" ;;
        core) grep -q '^PASS' "$out/$name.out" && ! grep -q '^FAIL' "$out/$name.out" &&
              [ "$(grep '^fingerprint' "$out/$name.out" | cut -d' ' -f2)" = "$(cat tests/lib/property/fingerprint.expected)" ] ;;
      esac
      result=$?
    else
      result=1
    fi
    if [ "$result" -eq 0 ]; then
      echo "PASS $host $label"
    elif why=$(deviation "native:$host" "$label"); then
      echo "EXPLAINED $host $label: $why"
    else
      echo "FAIL $host $label (see $out/$name.*)"
    fi
  done
done > "$out/results.txt"

cat "$out/results.txt"
passed=$(grep -c '^PASS' "$out/results.txt")
explained=$(grep -c '^EXPLAINED' "$out/results.txt")
failed=$(grep -c '^FAIL' "$out/results.txt")
echo "test-lib-hosts: $passed pass, $explained explained, $failed FAILED"
[ "$failed" -eq 0 ]
