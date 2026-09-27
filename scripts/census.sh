#!/bin/sh
# The census of a workload (docs/census.md):
#   scripts/census.sh [--out DIR] [--every BYTES] [--summary] [--timeout S] WORKLOAD...
# Each workload runs on the stock VM (bin/runevm-new --jit=off --count) and
# on the census VM (bin/runevm-census, `make vm-census`) with its traces in
# DIR/WORKLOAD (DIR defaults to tests/out/census); the two --count lines and
# the two outputs must agree, and DIR/WORKLOAD/DONE then records the count,
# the census's --stats line and the wall time. The census VM runs with a
# 1 GiB semispace and --heap-fill 50, so that only its forced collections,
# every BYTES bytes allocated (default 262144), sample the heap. --summary
# keeps census.txt alone (no trace files, no per-object memory: the mode
# for a program that allocates tens of gigabytes).
# Workloads: bootstrap (the compiler compiling its sources), compile-sigs,
# compile-hello, runedoc-ir, runedoc-page (the compiler and runedoc on the
# inputs of their tests/perf budgets, as register bytecode: bin/rune.rbc,
# bin/runedoc.rbc), a program of tests/perf (compiled by bin/rune-new,
# run with the args of its .budget), mlton-NAME (one of MLton's benchmarks
# at the size of tests/perf/mlton-bench.txt, prepared by
# tests/external/run-mlton-bench.sh --prepare), or a FILE.rbc of register
# bytecode. Exits 1 if a workload fails.
set -u
out=tests/out/census
every=262144
summary=""
tmo=3600
while [ $# -gt 0 ]; do
  case "$1" in
    --out) out=$2; shift 2 ;;
    --every) every=$2; shift 2 ;;
    --summary) summary="--census-summary"; shift ;;
    --timeout) tmo=$2; shift 2 ;;
    -*) echo "usage: scripts/census.sh [--out DIR] [--every BYTES] [--summary] [--timeout S] WORKLOAD..." >&2; exit 2 ;;
    *) break ;;
  esac
done
[ $# -gt 0 ] || { echo "scripts/census.sh: no workload" >&2; exit 2; }
cd "$(dirname "$0")/.."
root=$(pwd)
rune=${RUNE_NEW:-bin/rune-new}
stock=${RUNEVM_NEW:-$root/bin/runevm-new}
census=${RUNEVM_CENSUS:-$root/bin/runevm-census}
[ -x "$census" ] || { echo "scripts/census.sh: no $census (make vm-census)" >&2; exit 2; }
command -v timeout > /dev/null 2>&1 || tmo=""
limit() { if [ -n "$tmo" ]; then timeout "$tmo" "$@"; else "$@"; fi; }

boot_sources() {
  echo build/config.sml
  grep -v -E '^[[:space:]]*(#|$)' sources.txt
  echo src/main/rune-main.sml
}
budget_args() { sed -n 's/^args //p' "tests/perf/$1.budget"; }

status=0
for w in "$@"; do
  name=$(basename "$w" .rbc)
  dir=$out/$name
  mkdir -p "$dir"
  rm -f "$dir/DONE"
  heap=67108864
  cwd=$root
  args=""
  outfile=""
  case "$w" in
    bootstrap)
      rbc=bin/rune.rbc; outfile=$dir/boot.rbc; args="--lib lib -o $outfile $(boot_sources | tr '\n' ' ')" ;;
    compile-sigs|compile-hello)
      rbc=bin/rune.rbc; outfile=$dir/out.rbc; args="--lib lib -o $outfile $(sed -n 's/^compile //p' "tests/perf/$w.budget")" ;;
    runedoc-ir|runedoc-page)
      rbc=bin/runedoc.rbc; args="--lib lib $(eval echo "$(sed -n 's/^runedoc //p' "tests/perf/$w.budget")")" ;;
    mlton-*)
      cwd=$root/tests/out/mlton-bench
      sh tests/external/run-mlton-bench.sh --prepare --rune "$rune" "${w#mlton-}" > "$dir/prepare.out" 2>&1 || { echo "FAIL $w: $(tail -1 "$dir/prepare.out")"; status=1; continue; }
      rbc=$cwd/${w#mlton-}.rbc
      [ -f "$cwd/${w#mlton-}.args" ] && args=$(cat "$cwd/${w#mlton-}.args") ;;
    *.rbc)
      rbc=$w ;;
    *)
      [ -f "tests/perf/$w.sml" ] || { echo "FAIL $w: not a workload"; status=1; continue; }
      rbc=$dir/$w.rbc; args=$(budget_args "$w")
      "$rune" "tests/perf/$w.sml" -o "$rbc" 2> "$dir/compile.err" || { echo "FAIL $w: compile: $(head -1 "$dir/compile.err")"; status=1; continue; } ;;
  esac
  case "$rbc" in /*) ;; *) rbc=$root/$rbc ;; esac
  # The compiler looks at its output file before it writes it, and a run that
  # finds one counts differently from a run that does not (docs/testing.md):
  # each run starts without it.
  [ -n "$outfile" ] && rm -f "$outfile"
  # shellcheck disable=SC2086
  (cd "$cwd" && limit "$stock" --jit=off --count --heap-size $heap "$rbc" $args < /dev/null > "$dir/stock.stdout" 2> "$dir/stock.stderr")
  sx=$?
  sline=$(grep '^runevm: count:' "$dir/stock.stderr" | tail -1)
  t0=$(date +%s)
  [ -n "$outfile" ] && rm -f "$outfile"
  # shellcheck disable=SC2086
  (cd "$cwd" && limit "$census" --jit=off --count --stats --heap-size 1073741824 --heap-fill 50 --census-dir "$root/$dir" --census-every "$every" $summary "$rbc" $args < /dev/null > "$dir/census.stdout" 2> "$dir/census.stderr")
  cx=$?
  wall=$(( $(date +%s) - t0 ))
  cline=$(grep '^runevm: count:' "$dir/census.stderr" | tail -1)
  if [ $sx -ne 0 ]; then echo "FAIL $w: stock VM exit $sx: $(grep -v '^runevm: count\|^runevm: [0-9]* collections' "$dir/stock.stderr" | head -1)"; status=1; continue; fi
  if [ $cx -ne 0 ]; then echo "FAIL $w: census VM exit $cx: $(grep -v '^runevm: count\|^runevm: [0-9]* collections\|^runevm-census: progress' "$dir/census.stderr" | head -1)"; status=1; continue; fi
  if [ -z "$sline" ] || [ "$sline" != "$cline" ]; then echo "FAIL $w: counts differ: stock [$sline] census [$cline] (docs/testing.md: the same streams and directory for both?)"; status=1; continue; fi
  if ! cmp -s "$dir/stock.stdout" "$dir/census.stdout"; then echo "FAIL $w: the outputs differ"; status=1; continue; fi
  "$census" --census-static "$rbc" > "$dir/static.tsv" 2> /dev/null
  # cwd, cmd and out: how the stock VM was run, and the file it wrote, for tools/heapsim/validate.sh to run it again at other heap settings
  { echo "count $sline"; echo "wall $wall s"; echo "every $every"; [ -n "$summary" ] && echo "mode summary"; echo "cwd $cwd"; echo "cmd $rbc $args"; [ -n "$outfile" ] && echo "out $root/$outfile"; grep '^runevm: [0-9]* collections' "$dir/census.stderr"; } > "$dir/DONE"
  echo "ok   $w: $wall s; $cline"
done
exit $status
