#!/bin/sh
# M1 correctness runner. Timings and counts are added in M6.
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)
profile=${BENCH_PROFILE:-smoke}
configs=${BENCH_CONFIGS:-rune,hosts}
filter=${BENCH_FILTER:-}
routine=${BENCH_ROUTINE:-0}
while [ "$#" -gt 0 ]; do
  case $1 in
    --profile) profile=$2; shift 2 ;;
    --configs) configs=$2; shift 2 ;;
    --filter) filter=$2; shift 2 ;;
    --routine) routine=1; profile=smoke; shift ;;
    *) echo "usage: run-benchmarks.sh [--profile PROFILE] [--configs CONFIGS] [--filter TEXT]" >&2; exit 2 ;;
  esac
done
catalog=$root/build/bench-catalog.rbc
[ -f "$catalog" ] || { echo "run make bench-check to build the catalogue" >&2; exit 2; }
base=$root/tests/out/benchmarks/$profile
mkdir -p "$base"
out=$(mktemp -d "$base/run.XXXXXX")
printf '%s\n' "$out" > "$base/latest-run"
echo "BENCH OUTPUT $out"
if [ "$routine" = 1 ]; then
  "$root/bin/runevm" "$catalog" --routine "$filter" > "$out/jobs.tsv"
else
  "$root/bin/runevm" "$catalog" --list "$profile" "$filter" > "$out/jobs.tsv"
fi
[ -s "$out/jobs.tsv" ] || { echo "bench-check: no benchmark matches" >&2; exit 2; }
status=0
while IFS="$(printf '\t')" read -r name seconds memory sources args expected input_files; do
  job=$out/$name
  mkdir -p "$job"
  : > "$job/sources.txt"
  # Catalogue validation restricts paths to portable relative source names.
  for source in $sources; do printf '%s\n' "$root/examples/benchmarks/$source" >> "$job/sources.txt"; done
  { printf '%s\n%s\n' "$name" "$args"; cat "$root/examples/benchmarks/$expected"; } > "$job/input"
  : > "$job/data.txt"
  if [ "$input_files" != - ]; then
    for path in $input_files; do printf '%s\n' "$path" >> "$job/data.txt"; done
  fi
  echo "BENCH $name $profile"
  RUNE_MATRIX_TIMEOUT=$seconds RUNE_MATRIX_MEMORY=$memory \
    sh tests/basis/run-matrix.sh --configs "$configs" --program-list "$job/sources.txt" \
      --program-input "$job/input" --program-data "$root/examples/benchmarks/$name" --program-data-list "$job/data.txt" --program-out "$job/matrix" < /dev/null > "$job/result.log" 2>&1 || status=1
  grep -E '^(RESULT |PASS |FAIL |SUMMARY |PROGRAM |run-matrix:)' "$job/result.log" || true
done < "$out/jobs.tsv"
exit "$status"
