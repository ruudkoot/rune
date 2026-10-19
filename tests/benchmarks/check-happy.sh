#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/happy-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/hartel-ida-finite.sml examples/benchmarks/shared/happy-set.sml examples/benchmarks/shared/happy-lexer.sml examples/benchmarks/shared/happy-kernel.sml examples/benchmarks/shared/happy-check.sml tests/benchmarks/happy-fixtures.sml tests/benchmarks/happy-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=4194304 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/happy" \
      --program-data-list "$root/tests/benchmarks/data/happy/FILES" --program-out "$out/O$level" \
      < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-happy: validation failures ($out)" >&2; exit 1; fi
echo "bench-happy: complete generated parsers, warnings, literals, semantic actions, set shapes, demand and sharing checks hold ($out)"
