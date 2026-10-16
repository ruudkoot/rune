#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/sandmark-numerical-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/sandmark-levinson.sml examples/benchmarks/shared/levinson-files.sml examples/benchmarks/shared/sandmark-qr.sml examples/benchmarks/shared/sandmark-crout.sml examples/benchmarks/shared/numerical-matrix-files.sml examples/benchmarks/shared/qr-check.sml examples/benchmarks/shared/sandmark-durand-kerner.sml examples/benchmarks/shared/durand-kerner-files.sml tests/benchmarks/levinson-tests.sml tests/benchmarks/numerical-matrix-tests.sml tests/benchmarks/durand-kerner-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; exit 1; }
done
echo "bench-sandmark-numerical: numerical results, source limitations and negative checks hold ($out)"
