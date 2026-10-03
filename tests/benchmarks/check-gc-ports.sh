#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/gc-port-checks.XXXXXX")
printf 'structure GC = Benchmark\n' > "$out/alias.sml"
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/gc_bench/benchmark.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
printf '%s\n' "$out/alias.sml" >> "$out/sources.txt"
for source in examples/benchmarks/hash/benchmark.sml tests/benchmarks/gc-ports.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done >> "$out/sources.txt"
for level in 0 2; do
  RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=4194304 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,native:mlton,native:smlnj-legacy,native:polyml,native:smlnj-dev}" \
      --program-list "$out/sources.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; exit 1; }
done
echo "bench-gc-ports: full tree shape/labels and hash entries are validated ($out)"
