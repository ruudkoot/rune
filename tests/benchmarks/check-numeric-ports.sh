#!/bin/sh
# Independent numerical references and deliberately perturbed full states.
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/numeric-port-checks.XXXXXX")
mkdir -p "$out/data/expected"
cp examples/benchmarks/kahan/expected/smoke.txt "$out/data/expected/smoke.txt"
printf '0.0 0.0\n' > "$out/data/integration-reference.txt"
printf 'expected/smoke.txt\nintegration-reference.txt\n' > "$out/data-list"
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/kahan/benchmark.sml examples/benchmarks/shared/x2n1.sml examples/benchmarks/shared/integrate.sml examples/benchmarks/shared/rational.sml examples/benchmarks/shared/nofib-hash.sml tests/benchmarks/numeric-ports.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for level in 0 2; do
  RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=4194304 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,native:mlton,native:smlnj-legacy,native:polyml,native:smlnj-dev}" \
      --program-list "$out/sources.txt" --program-data "$out/data" --program-data-list "$out/data-list" \
      --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; exit 1; }
done
echo "bench-numeric-ports: independent references and state corruption checks hold ($out)"
