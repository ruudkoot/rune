#!/bin/sh
# Checked catalogue order plus independent portable application assertions.
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
family=$1
case "$family" in parser|reptile|hpg|fluid) ;; *) echo "unknown nofib application" >&2; exit 2 ;; esac
catalog=$root/build/bench-catalog.rbc
[ -f "$catalog" ] || { echo "build the catalogue with make bench-check first" >&2; exit 2; }
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/nofib-$family-checks.XXXXXX")
"$root/bin/runevm" "$catalog" --list smoke "=$family-lazy" > "$out/catalogue.tsv"
[ "$(wc -l < "$out/catalogue.tsv")" = 1 ] || { echo "expected one checked source-order entry" >&2; exit 2; }
sources=$(cut -f 4 "$out/catalogue.tsv")
{
  printf '%s\n' "$root/tests/basis/harness.sml" "$root/tests/benchmarks/application-test-io.sml"
  for source in $sources; do
    case "$source" in "$family-lazy/benchmark.sml"|shared/main.sml) ;;
      *) printf '%s\n' "$root/examples/benchmarks/$source" ;;
    esac
  done
  printf '%s\n' "$root/tests/benchmarks/nofib-$family-tests.sml" "$root/tests/basis/finish.sml"
} > "$out/sources.txt"
configs=${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}
status=0
for level in 0 2; do
  selected=$configs
  if [ "$level" = 0 ]; then
    selected=""
    config_ifs=$IFS
    IFS=,
    for config in $configs; do
      case "$config" in hosts|native:*) ;;
        *) if [ -z "$selected" ]; then selected=$config; else selected=$selected,$config; fi ;;
      esac
    done
    IFS=$config_ifs
    [ -n "$selected" ] || continue
  fi
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=4194304 \
    sh tests/basis/run-matrix.sh --configs "$selected" --program-list "$out/sources.txt" \
      --program-data "$root" --program-data-list "$root/tests/benchmarks/data/nofib-$family/FILES" \
      --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 ||
      { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-nofib-$family: validation failures ($out)" >&2; exit 1; fi
echo "bench-nofib-$family: independent source fixtures, complete outputs and demand/sharing checks hold ($out)"
