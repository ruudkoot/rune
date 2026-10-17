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
# Numerical validators raise an explicit correctness exception; classify its
# actual portable-driver output separately from an ordinary runtime exception.
. "$root/scripts/benchmark-result.sh"
for failure in numeric runtime; do
  phase_dir=$out/$failure-error
  mkdir -p "$phase_dir"
  case $failure in
    numeric) expression='raise Fail "incorrect result: perturbed numerical value"'; expected_category=incorrect-result ;;
    runtime) expression='raise Div'; expected_category=runtime-failure ;;
  esac
  printf 'structure Benchmark = struct val name="negative" fun run (_:string list):string = %s end\n' "$expression" > "$phase_dir/benchmark.sml"
  bin/rune --lint examples/benchmarks/shared/input.sml "$phase_dir/benchmark.sml" examples/benchmarks/shared/measure.sml "$out/launch.sml" -o "$phase_dir/prog.rbc"
  printf 'negative\nunused\nunused\n1\n' > "$phase_dir/input"
  phase_exit=0
  bin/runevm "$phase_dir/prog.rbc" < "$phase_dir/input" > "$phase_dir/stdout" 2> "$phase_dir/stderr" || phase_exit=$?
  [ "$phase_exit" != 0 ] || { echo 'exception accepted as a successful measurement' >&2; exit 1; }
  rounds=1; status=0
  validate
  [ "$category" = "$expected_category" ] && [ "$status" = 1 ] || { echo 'measurement exception category differs' >&2; exit 1; }
  ! grep -q '^SAMPLE ' "$phase_dir/stdout"
done
echo 'bench-measurement: numerical correctness and runtime exceptions have distinct failure categories'
# Captured General.exnMessage formats differ among native hosts. In particular,
# Poly/ML quotes a Fail payload instead of using the colon prefix.
for format in bare colon quoted quoted_runtime; do
  phase_dir=$out/message-$format
  mkdir -p "$phase_dir"
  : > "$phase_dir/stderr"
  case $format in
    bare) message='FAIL negative -- incorrect result: numeric fixture'; expected_category=incorrect-result ;;
    colon) message='FAIL negative -- Fail: incorrect result: numeric fixture'; expected_category=incorrect-result ;;
    quoted) message='FAIL negative -- Fail "incorrect result"'; expected_category=incorrect-result ;;
    quoted_runtime) message='FAIL negative -- Fail "ordinary runtime failure"'; expected_category=runtime-failure ;;
  esac
  printf '%s\n' "$message" > "$phase_dir/stdout"
  phase_exit=1; rounds=1; status=0
  validate
  [ "$category" = "$expected_category" ] && [ "$status" = 1 ] || {
    echo "measurement misclassified $format exception format" >&2; exit 1;
  }
done
echo 'bench-measurement: bare, colon and quoted correctness failures are distinguished from runtime failures'
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
