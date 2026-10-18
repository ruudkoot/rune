#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/nucleic2-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/hartel-ida-finite.sml examples/benchmarks/shared/finite-binary32.sml examples/benchmarks/shared/nucleic2-kernel.sml examples/benchmarks/shared/nucleic2-check.sml tests/benchmarks/nucleic2-oracle.sml tests/benchmarks/nucleic2-precision.sml tests/benchmarks/nucleic2-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
status=0
configs=${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}
for level in 0 2; do
  selected=$configs
  if [ "$level" = 0 ]; then
    # Native hosts use default compiler options, so exercise them once.
    selected=""
    config_ifs=$IFS
    IFS=,
    for config in $configs; do
      case $config in
        hosts|native:*) ;;
        *) selected="${selected:+$selected,}$config" ;;
      esac
    done
    IFS=$config_ifs
    [ -n "$selected" ] || continue
  fi
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=4194304 \
    sh tests/basis/run-matrix.sh --configs "$selected" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/nucleic2" \
      --program-data-list "$root/tests/benchmarks/data/nucleic2/FILES" --program-out "$out/O$level" \
      < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-nucleic2: validation failures ($out)" >&2; exit 1; fi
echo "bench-nucleic2: complete conformations, coordinates, precision, pruning, demand, sharing and result checks hold ($out)"
