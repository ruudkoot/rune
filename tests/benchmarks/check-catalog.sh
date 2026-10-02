#!/bin/sh
# Corrupted metadata must fail before a compiler or measured workload runs.
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
out=$(mktemp -d "$root/tests/out/benchmarks/catalog-tests.XXXXXX")
suite=$out/examples/benchmarks
mkdir -p "$suite/shared" "$suite/tak"
awk -F '\t' 'NR==1 || ($1=="tak" && $2!="large")' examples/benchmarks/manifest.tsv > "$suite/manifest.tsv"
cp examples/benchmarks/inventory.tsv "$suite/"
cp examples/benchmarks/shared/input.sml examples/benchmarks/shared/tak.sml examples/benchmarks/shared/main.sml "$suite/shared/"
cp examples/benchmarks/tak/benchmark.sml examples/benchmarks/tak/smoke.expected examples/benchmarks/tak/normal.expected "$suite/tak/"
printf 'benchmark\treason\ntak\trecursive pilot\n' > "$suite/routine.tsv"
(cd "$out" && "$root/bin/runevm" "$root/build/bench-catalog.rbc" --check) > "$out/valid.log"
reject() {
  label=$1
  if (cd "$out" && "$root/bin/runevm" "$root/build/bench-catalog.rbc" --check) > "$out/$label.log" 2>&1; then
    echo "corrupt catalogue accepted: $label" >&2; exit 1
  fi
}
printf 'benchmark\treason\nmissing\tunknown program\n' > "$suite/routine.tsv"
reject unknown-routine
printf 'benchmark\treason\ntak\tfirst\ntak\tduplicate\n' > "$suite/routine.tsv"
reject duplicate-routine
printf 'benchmark\treason\ntak\t\n' > "$suite/routine.tsv"
reject missing-reason
printf 'benchmark\treason\ntak\tvalid\n' > "$suite/routine.tsv"
cp "$suite/manifest.tsv" "$out/original.tsv"
tail -1 "$out/original.tsv" >> "$suite/manifest.tsv"
reject duplicate-profile
cp "$out/original.tsv" "$suite/manifest.tsv"
rm "$suite/tak/normal.expected"
reject missing-fixture
echo 'bench-catalog: unknown/duplicate routine entries, missing reason, duplicate profiles and missing fixtures rejected'
