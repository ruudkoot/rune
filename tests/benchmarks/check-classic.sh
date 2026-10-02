#!/bin/sh
# Result validation beyond the ordinary profiles.
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
python3 tests/benchmarks/smith-oracle.py
python3 tests/benchmarks/kb-oracle.py
out=$root/tests/out/benchmarks/classic-validation
mkdir -p "$out"
for suite in checksum md5 numerical render ppm vliw; do
  {
    printf '%s\n' "$root/tests/basis/harness.sml" "$root/examples/benchmarks/shared/input.sml"
    case $suite in
      numerical) ;;
      ppm) printf '%s\n' "$root/examples/benchmarks/shared/ppm.sml" ;;
      render) printf '%s\n' "$root/examples/benchmarks/raytrace/check.sml" ;;
      vliw) printf '%s\n' "$root/examples/benchmarks/shared/files.sml" "$root/examples/benchmarks/vliw/benchmark.sml" ;;
      *) printf '%s\n' "$root/examples/benchmarks/$suite/benchmark.sml" ;;
    esac
    printf '%s\n' "$root/tests/benchmarks/$suite.sml" "$root/tests/basis/finish.sml"
  } > "$out/$suite.sources"
  RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=4194304 sh tests/basis/run-matrix.sh \
    --configs "${BENCH_CONFIGS:-rune,hosts}" --program-list "$out/$suite.sources" \
    --program-out "$out/$suite" < /dev/null > "$out/$suite.log" 2>&1 || { cat "$out/$suite.log"; exit 1; }
  grep -E '^(SUMMARY |PROGRAM PASS )' "$out/$suite.log"
done
