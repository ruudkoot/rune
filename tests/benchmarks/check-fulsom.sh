#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/fulsom-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/stream.sml examples/benchmarks/shared/hartel-ida-finite.sml examples/benchmarks/shared/fulsom-interval.sml examples/benchmarks/shared/fulsom-kernel.sml examples/benchmarks/shared/fulsom-check.sml tests/benchmarks/fulsom-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
printf '%s\n' depth-0.hex depth-1.hex depth-2.hex depth-3.hex depth-4.hex depth-5.hex > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/fulsom" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-fulsom: validation failures ($out)" >&2; exit 1; fi
echo "bench-fulsom: original interval, complete raster/hash and demand checks hold ($out)"
