#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/binarytrees5-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/binary-tree.sml examples/benchmarks/shared/sandmark-binarytrees5.sml tests/benchmarks/binarytrees5-checks.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
printf '%s\n' 6.expected > "$out/data.txt"
for level in 0 2; do
  RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/binarytrees5" --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; exit 1; }
done
echo "bench-binarytrees5: semantic and actual-output checks hold ($out)"
