#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/gamteb-checks.XXXXXX")
configs=${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}
for file in tests/benchmarks/data/gamteb/*; do basename "$file"; done > "$out/data.txt"
status=0
for part in kernel checker; do
  {
    for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/stream.sml examples/benchmarks/shared/nofib-gamteb-math.sml examples/benchmarks/shared/nofib-gamteb-tables.sml examples/benchmarks/shared/nofib-gamteb.sml; do
      printf '%s\n' "$root/$source"
    done
    if [ "$part" = checker ]; then
      printf '%s\n' "$root/examples/benchmarks/shared/nofib-gamteb-driver.sml" "$root/tests/benchmarks/gamteb-tests.sml"
    else
      printf '%s\n' "$root/tests/benchmarks/gamteb-kernel-tests.sml"
    fi
    printf '%s\n' "$root/tests/basis/finish.sml"
  } > "$out/sources-$part.txt"
  for level in 0 2; do
    RUNE_MATRIX_RUN="$out/worker-$part-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
      sh tests/basis/run-matrix.sh --configs "$configs" \
        --program-list "$out/sources-$part.txt" --program-data "$root/tests/benchmarks/data/gamteb" \
        --program-data-list "$out/data.txt" --program-out "$out/$part-O$level" < /dev/null > "$out/$part-O$level.log" 2>&1 || { cat "$out/$part-O$level.log"; status=1; }
  done
done
if [ "$status" != 0 ]; then echo "bench-gamteb: validation failures ($out)" >&2; exit 1; fi
echo "bench-gamteb: raw streams, source physics, numerical checks and demand checks hold ($out)"
