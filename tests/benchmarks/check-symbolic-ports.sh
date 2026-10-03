#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/symbolic-port-checks.XXXXXX")
printf 'structure ParaffinBenchmark = Benchmark\n' > "$out/alias.sml"
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/stream.sml examples/benchmarks/shared/paraffins.sml examples/benchmarks/paraffins-lazy/benchmark.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
printf '%s\n' "$out/alias.sml" >> "$out/sources.txt"
for source in examples/benchmarks/shared/regex.sml examples/benchmarks/gen_regexps-lazy/benchmark.sml tests/benchmarks/symbolic-ports.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done >> "$out/sources.txt"
for level in 0 2; do
  RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=4194304 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; exit 1; }
done
echo "bench-symbolic-ports: unforced tree values and ordered range expansion hold ($out)"
