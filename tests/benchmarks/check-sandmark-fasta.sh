#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/fasta-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/sandmark-fasta.sml examples/benchmarks/shared/fasta-cycle-check.sml tests/benchmarks/sandmark-fasta-checks.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
printf '%s\n' alu.data fasta3-iub.cycle fasta3-homo.cycle fasta3-smoke.output fasta6-smoke.output > "$out/data.txt"
for level in 0 2; do
  RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/sandmark-fasta" --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; exit 1; }
done
echo "bench-fasta: semantic and actual-output checks hold ($out)"
