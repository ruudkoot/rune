#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/minilight-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/ocaml-random.sml examples/benchmarks/shared/minilight-vector.sml examples/benchmarks/shared/minilight-parse.sml examples/benchmarks/shared/minilight-delay.sml examples/benchmarks/shared/minilight-random.sml examples/benchmarks/shared/minilight-triangle.sml examples/benchmarks/shared/minilight-spatial.sml examples/benchmarks/shared/minilight-scene.sml examples/benchmarks/shared/minilight-surface.sml examples/benchmarks/shared/minilight-ray.sml examples/benchmarks/shared/minilight-image.sml examples/benchmarks/shared/minilight-camera.sml examples/benchmarks/shared/minilight-check.sml tests/benchmarks/minilight-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
for file in smoke.model smoke.reference; do printf '%s\n' "$file"; done > "$out/data.txt"
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/minilight" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-minilight: validation failures ($out)" >&2; exit 1; fi
echo "bench-minilight: source render snapshots, random state, identity and demand checks agree ($out)"
