#!/bin/sh
# Actual native compiler exit status and phase must survive the matrix adapter.
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/matrix-status.XXXXXX")
cat > "$out/mlton" <<'STUB'
#!/bin/sh
if [ "$#" = 0 ]; then echo 'MLton 999.0'; exit 0; fi
if [ "$MATRIX_FAULT" = timeout ]; then exec sleep 5; fi
echo 'planted compiler error' >&2
exit 7
STUB
cat > "$out/mlkit" <<'STUB'
#!/bin/sh
if [ "$1" = --version ]; then echo 'MLKit v999.0'; exit 0; fi
if [ "$MATRIX_FAULT" = timeout ]; then exec sleep 5; fi
echo 'planted compiler error' >&2
exit 7
STUB
chmod +x "$out/mlton" "$out/mlkit"
printf '%s\n' "$root/examples/benchmarks/shared/input.sml" > "$out/sources.txt"
for host in mlton mlkit; do
  for mode in error timeout; do
    expected=7
    [ "$mode" != timeout ] || expected=124
    job=$out/$host-$mode
    if MATRIX_FAULT=$mode MLTON="$out/mlton" MLKIT="$out/mlkit" MLKIT_LIB="$out" \
       RUNE_MATRIX_RUN="$job-worker" RUNE_MATRIX_TIMEOUT=1 \
       sh tests/basis/run-matrix.sh --configs "native:$host" \
       --program-list "$out/sources.txt" --program-out "$job" \
       > "$job.log" 2>&1; then
      echo "matrix accepted planted $host $mode" >&2; exit 1
    fi
    grep -Fq "PROGRAM FAIL native:$host@999.0 (load 1, exit $expected)" "$job.log"
    if [ "$mode" = timeout ]; then
      grep -Fq 'compile timed out after 1 s' "$job/native-$host-999.0/program/log"
    else
      grep -Fq 'planted compiler error' "$job/native-$host-999.0/program/log"
    fi
    [ ! -s "$job/native-$host-999.0/program/stdout" ]
  done
done
echo "bench-matrix: native compiler errors and compile timeouts retain their actual status and phase ($out)"
