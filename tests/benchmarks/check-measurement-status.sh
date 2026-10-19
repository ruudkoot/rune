#!/bin/sh
# An absent export must not erase the process status of an SML/NJ compile.
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/measurement-status.XXXXXX")
cat > "$out/sml" <<'STUB'
#!/bin/sh
if [ "$1" = @SMLversion ]; then echo 'sml 999.0'; exit 0; fi
case "$MEASUREMENT_FAULT" in
  error) echo 'planted compiler error' >&2; exit 7 ;;
  timeout) echo 'planted deadline status' >&2; exit 124 ;;
  no_image) exit 0 ;;
esac
exit 8
STUB
chmod +x "$out/sml"
for mode in error timeout no_image; do
  expected=compile-error; raw_exit=7
  case "$mode" in timeout) expected=timeout; raw_exit=124 ;; no_image) raw_exit=0 ;; esac
  if MEASUREMENT_FAULT=$mode SMLNJ="$out/sml" \
     sh scripts/measure-benchmarks.sh time --profile smoke --filter '=tak' \
       --configs native:smlnj-legacy --samples 1 > "$out/$mode.log" 2>&1; then
    echo "measurement accepted planted SML/NJ $mode" >&2; exit 1
  fi
  run=$(sed -n 's/^BENCH MEASUREMENT //p' "$out/$mode.log")
  [ -n "$run" ]
  phase=$run/tak/native-smlnj-legacy/build/compile
  [ "$(cat "$phase/exit")" = "$raw_exit" ]
  awk -F '\t' -v expected="$expected" '
    NR==1 { next }
    $5=="compile" && $8==expected { compiled++; next }
    { bad++ }
    END { exit !(compiled==1 && bad==0) }
  ' "$run/samples.tsv"
  if [ "$mode" = no_image ]; then
    grep -Fq 'without an exported SML/NJ image' "$phase/stderr"
  fi
done
echo "bench-measurement: compiler exits, deadlines and missing exports remain distinct ($out)"
