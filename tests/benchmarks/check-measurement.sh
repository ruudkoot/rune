#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
out=$(mktemp -d "$root/tests/out/benchmarks/measurement-tests.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/report.sml examples/benchmarks/shared/counts.sml tests/benchmarks/measurement.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources"
sh tests/basis/run-matrix.sh --configs rune,native:mlton,native:smlnj-legacy,native:polyml --program-list "$out/sources" --program-out "$out/checks" < /dev/null > "$out/checks.log" 2>&1
[ "$(grep -c '^PROGRAM PASS ' "$out/checks.log")" = 4 ] || { cat "$out/checks.log"; exit 1; }
echo 'bench-measurement: statistics, execution-model comparisons and budget failures passed on four compilers'
# Exercise the portable measurement entrypoint with a deliberately wrong fixture.
# Add the same portable launch used by the adapter.
echo 'val _ = OS.Process.exit (BenchMeasure.main ())' > "$out/launch.sml"
bin/rune --lint examples/benchmarks/shared/input.sml examples/benchmarks/tak/benchmark.sml examples/benchmarks/shared/measure.sml "$out/launch.sml" -o "$out/negative.rbc"
printf 'tak\n18 12 6 1\n999\n3\n' > "$out/input"
if bin/runevm "$out/negative.rbc" < "$out/input" > "$out/negative.out"; then echo 'wrong result accepted' >&2; exit 1; fi
! grep -q '^SAMPLE ' "$out/negative.out"
grep -q '^FAIL ' "$out/negative.out"
echo 'bench-measurement: wrong results supply no repeated timing samples'
