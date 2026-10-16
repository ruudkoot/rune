#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/zarith-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/zarith-integers.sml examples/benchmarks/shared/zarith-pi.sml tests/benchmarks/sandmark-zarith.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for size in 0 1 9 10 11 27; do
  printf 'pi-%s.expected\n' "$size"
done > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=4194304 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/zarith" --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || status=1
  cat "$out/O$level.log"
done
echo "bench-zarith: numeric modes, recurrence bases, repeated calls and full pi output checked ($out)"
exit "$status"
