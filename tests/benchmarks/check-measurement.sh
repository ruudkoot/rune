#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
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
bin/rune --target=stack --lint examples/benchmarks/shared/input.sml examples/benchmarks/shared/tak.sml examples/benchmarks/tak/benchmark.sml examples/benchmarks/shared/measure.sml "$out/launch.sml" -o "$out/negative.rbc"
printf 'tak\n18 12 6 1\n999\n3\n' > "$out/input"
if bin/runevm-stack "$out/negative.rbc" < "$out/input" > "$out/negative.out"; then echo 'wrong result accepted' >&2; exit 1; fi
! grep -q '^SAMPLE ' "$out/negative.out"
grep -q '^FAIL ' "$out/negative.out"
echo 'bench-measurement: wrong results supply no repeated timing samples'
if RUNEVM_OPTIONS=--count sh scripts/measure-benchmarks.sh time --filter tak > "$out/instrumented.log" 2>&1; then
  echo 'instrumented run accepted as headline timing' >&2; exit 1
fi
grep -q 'instrumented VM options' "$out/instrumented.log"
echo 'bench-measurement: instrumentation rejected from headline timing'
# A resolver must not reuse an inherited matrix worker directory: separate
# tool invocations can have the same shell PID in isolated PID namespaces.
mkdir -p "$out/shared-run"
printf 'keep this matrix worker\n' > "$out/shared-run/keep"
RUNE_MATRIX_RUN="$out/shared-run" sh scripts/measure-benchmarks.sh count \
  --profile smoke --filter primes-strict --configs rune > "$out/isolated.log" 2>&1
[ "$(cat "$out/shared-run/keep")" = 'keep this matrix worker' ] || { echo 'measurement removed another matrix worker' >&2; exit 1; }
measurement=$(sed -n 's/^BENCH MEASUREMENT //p' "$out/isolated.log")
[ "$(wc -l < "$measurement/primes-strict/rune/config.tsv")" = 1 ] || { echo 'configuration resolution collided' >&2; exit 1; }
echo 'bench-measurement: configuration resolution preserves other matrix workers'
