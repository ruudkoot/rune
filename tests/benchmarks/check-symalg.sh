#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/symalg-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/symalg-real.sml examples/benchmarks/shared/symalg-number.sml examples/benchmarks/shared/symalg-kernel.sml examples/benchmarks/shared/symalg-check.sml tests/benchmarks/symalg-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
printf '%s\n' commands.stdin commands.stdout smoke-corrupt.numbers.reference smoke-corrupt.stdout smoke.numbers.reference smoke.stdin smoke.stdout > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/symalg" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-symalg: validation failures ($out)" >&2; exit 1; fi
echo "bench-symalg: source arithmetic, complete values, transcripts and demand controls hold ($out)"
