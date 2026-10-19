#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/scs-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/stream.sml examples/benchmarks/shared/infer-parsing.sml examples/benchmarks/shared/scs-rational.sml examples/benchmarks/shared/scs-matrix.sml examples/benchmarks/shared/scs-types.sml examples/benchmarks/shared/scs-prepare.sml examples/benchmarks/shared/scs-random.sml examples/benchmarks/shared/scs-simulate.sml examples/benchmarks/shared/scs-parse.sml examples/benchmarks/shared/scs-check.sml tests/benchmarks/scs-bits.sml tests/benchmarks/scs-cases.sml tests/benchmarks/scs-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for file in tests/benchmarks/data/scs/*; do basename "$file"; done > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=180 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/scs" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-scs: validation failures ($out)" >&2; exit 1; fi
echo "bench-scs: circuit traces, exact arithmetic, RNG demand, numerical bounds and host regressions hold ($out)"
