#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/fem-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/hartel-ida-finite.sml examples/benchmarks/shared/nofib-linear-float.sml examples/benchmarks/shared/fem-float.sml examples/benchmarks/shared/fem-arrays.sml examples/benchmarks/shared/fem-kernel.sml examples/benchmarks/shared/fem-snapshot.sml examples/benchmarks/shared/fem-report.sml examples/benchmarks/shared/fem-check.sml tests/benchmarks/fem-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
cp "$root/tests/benchmarks/data/fem/FILES" "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/fem" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-fem: validation failures ($out)" >&2; exit 1; fi
echo "bench-fem: complete binary32 FEM states, cyclic arrays, reports and result checks hold ($out)"
