#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/stdlib-str-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/ocaml-stdlib-text-input.sml examples/benchmarks/shared/ocaml-stdlib-text.sml examples/benchmarks/shared/ocaml-stdlib-text-program.sml examples/benchmarks/shared/sandmark-regexredux-str.sml examples/benchmarks/shared/ocaml-stdlib-str.sml tests/benchmarks/stdlib-str-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
: > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-stdlib-str: validation failures ($out)" >&2; exit 1; fi
echo "bench-stdlib-str: original Str operations, match state and literal models agree ($out)"
