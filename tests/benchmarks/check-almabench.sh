#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/almabench-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/sandmark-almabench-tables.sml examples/benchmarks/shared/sandmark-almabench.sml examples/benchmarks/shared/sandmark-almabench-driver.sml tests/benchmarks/almabench-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for file in tests/benchmarks/data/almabench/*; do basename "$file"; done > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/almabench" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-almabench: validation failures ($out)" >&2; exit 1; fi
echo "bench-almabench: original and ERFA states, angle semantics and aggregate checks hold ($out)"
