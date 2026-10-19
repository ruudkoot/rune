#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/coverage-tests.XXXXXX")
for file in tests/basis/harness.sml examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/coverage.sml tests/benchmarks/coverage.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$file"
done > "$out/sources.txt"
{
  printf '%s\n' examples/benchmarks/manifest.tsv examples/benchmarks/inventory.tsv examples/benchmarks/source-variants.tsv examples/benchmarks/README.md
  awk -F '\t' 'NR>1 && !seen[$1]++ { print "examples/benchmarks/" $1 "/PROVENANCE.md" }' examples/benchmarks/manifest.tsv
} > "$out/data.txt"
RUNE_MATRIX_RUN="$out/worker" sh tests/basis/run-matrix.sh \
  --configs rune,native:mlton,native:smlnj-legacy,native:polyml \
  --program-list "$out/sources.txt" --program-out "$out/checks" \
  --program-data "$root" --program-data-list "$out/data.txt" \
  < /dev/null > "$out/checks.log" 2>&1
[ "$(grep -c '^PROGRAM PASS ' "$out/checks.log")" = 4 ] || { cat "$out/checks.log"; exit 1; }
echo "bench-coverage: complete imports, rejected omissions/deferred entries, companions and documentation hold on four compilers ($out)"
