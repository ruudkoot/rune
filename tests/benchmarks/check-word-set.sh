#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/set-checks.XXXXXX")
mkdir -p "$out/data"
cp tests/benchmarks/data/set-dictionary.txt "$out/data/dictionary.txt"
cp tests/benchmarks/data/set-shape.txt "$out/data/shape.txt"
printf 'dictionary.txt\nshape.txt\n' > "$out/data-list"
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/stream.sml examples/benchmarks/shared/word-set.sml examples/benchmarks/shared/spellcheck.sml tests/benchmarks/word-set.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for level in 0 2; do
  RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=4194304 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$out/data" --program-data-list "$out/data-list" \
      --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; exit 1; }
done
echo "bench-word-set: balance, membership, tree shape and encoding hold ($out)"
