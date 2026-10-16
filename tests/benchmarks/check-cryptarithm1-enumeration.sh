#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/cryptarithm1-enumeration.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/cell-sequence.sml examples/benchmarks/shared/nofib-cryptarithm1.sml tests/benchmarks/cryptarithm1-enumeration.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
RUNE_BENCH_COMPILE_OPTIONS=-O2 RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=1048576 \
  sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,native:mlton}" \
    --program-list "$out/sources.txt" --program-out "$out/matrix" < /dev/null > "$out/result.log" 2>&1 || { cat "$out/result.log"; exit 1; }
echo "bench-cryptarithm1: all 3628800 candidates visited and result checked ($out)"
