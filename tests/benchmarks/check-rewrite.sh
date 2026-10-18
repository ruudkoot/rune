#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/rewrite-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/stream.sml examples/benchmarks/shared/nofib-rewrite-expr.sml examples/benchmarks/shared/nofib-rewrite-parser.sml examples/benchmarks/shared/nofib-rewrite-kernel.sml examples/benchmarks/shared/nofib-rewrite-driver.sml tests/benchmarks/rewrite-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for file in tests/benchmarks/data/rewrite/*; do basename "$file"; done > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/rewrite" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-rewrite: validation failures ($out)" >&2; exit 1; fi
echo "bench-rewrite: original completion theory, independent free-group forms, substitutions and demand checks hold ($out)"
