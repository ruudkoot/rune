#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/sandmark-kb-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/sandmark-kb-terms.sml examples/benchmarks/shared/sandmark-kb-rewrite-raise.sml examples/benchmarks/shared/sandmark-kb-rewrite-option.sml examples/benchmarks/shared/sandmark-kb-order.sml examples/benchmarks/shared/sandmark-kb-completion.sml examples/benchmarks/shared/sandmark-kb-data.sml examples/benchmarks/shared/sandmark-kb-driver.sml tests/benchmarks/sandmark-kb-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for file in tests/benchmarks/data/sandmark-kb/*; do basename "$file"; done > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/sandmark-kb" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-sandmark-kb: validation failures ($out)" >&2; exit 1; fi
echo "bench-sandmark-kb: source completed rules, critical pairs, matching and unification controls hold ($out)"
