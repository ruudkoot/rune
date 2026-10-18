#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/lexifi-g2pp-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/ocaml-random.sml examples/benchmarks/shared/lexifi-g2pp-date.sml examples/benchmarks/shared/lexifi-g2pp-math.sml examples/benchmarks/shared/lexifi-g2pp-random.sml examples/benchmarks/shared/lexifi-g2pp-optimization.sml examples/benchmarks/shared/lexifi-g2pp-calibration.sml examples/benchmarks/shared/lexifi-g2pp-input.sml examples/benchmarks/shared/lexifi-g2pp-check.sml examples/benchmarks/shared/lexifi-g2pp-driver.sml tests/benchmarks/lexifi-g2pp-support-tests.sml tests/benchmarks/lexifi-g2pp-de-tests.sml tests/benchmarks/lexifi-g2pp-check-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for file in smoke.reference; do printf '%s\n' "$file"; done > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/lexifi-g2pp" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-lexifi-g2pp: validation failures ($out)" >&2; exit 1; fi
echo "bench-lexifi-g2pp: source calibration prices, optimizer traces and numerical controls hold ($out)"
