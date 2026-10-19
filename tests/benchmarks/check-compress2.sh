#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/compress2-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/cell-sequence.sml examples/benchmarks/shared/compress2-bits.sml examples/benchmarks/shared/compress2.sml tests/benchmarks/compress2-writer-checks.sml tests/benchmarks/compress2-checks.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
printf '%s\n' smoke.input smoke-cuts/cut-00.bin smoke-cuts/cut-01.bin smoke-cuts/cut-02.bin smoke-cuts/cut-03.bin smoke-cuts/cut-04.bin smoke-cuts/cut-05.bin smoke-cuts/cut-06.bin smoke-cuts/cut-07.bin smoke-cuts/cut-08.bin smoke-cuts/cut-09.bin smoke-cuts/cut-10.bin smoke-cuts/cut-11.bin smoke-cuts/cut-12.bin smoke-cuts/cut-13.bin smoke-cuts/cut-14.bin smoke-cuts/cut-15.bin smoke-cuts/cut-16.bin smoke-cuts/cut-17.bin smoke-cuts/cut-18.bin smoke-cuts/cut-19.bin smoke-cuts/cut-20.bin smoke-cuts/cut-21.bin smoke-cuts/cut-22.bin smoke-cuts/cut-23.bin smoke-cuts/cut-24.bin smoke-cuts/cut-25.bin smoke-cuts/cut-26.bin smoke-cuts/cut-27.bin smoke-cuts/cut-28.bin smoke-cuts/cut-29.bin smoke-cuts/cut-30.bin writer-0.expected writer-1.expected writer-2.expected writer-3.expected writer-4.expected writer-5.expected writer-6.expected writer-7.expected > "$out/data.txt"
for level in 0 2; do
  RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/compress2" --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; exit 1; }
done
echo "bench-compress2: semantic and actual-output checks hold ($out)"
