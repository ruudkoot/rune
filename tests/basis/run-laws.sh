#!/bin/sh
# The laws of the Basis Library's documentation, run (docs/plans/quickcheck.md,
# M8, D9 and D13).
#   tests/basis/run-laws.sh [-j N] [FILTER]
# `runedoc --laws` writes a program for each signature with a law, holding
# every law at every structure that implements the signature. Each program
# whose name contains FILTER is compiled with `rune --library test/property`
# and run with at most $LAWS_MEMORY megabytes (default 4096), printing a line
# before each law and each of its cases, under a watchdog that stops it when a
# case has run $LAWS_TIMEOUT seconds (default 60). A case that the machine
# cannot hold, because the memory runs out or the watchdog stops it, is
# skipped: the program is started again with that case skipped
# (RUNE_PROPERTY_SKIP), from the law it was in (RUNE_PROPERTY_AFTER), and the
# law is judged on its other cases. A law with ten such cases is STOPPED and
# the program goes on after it. (A case that goes past a million reads and
# calls of the property library's own is discarded inside the program.) In
# tests/out/laws: the programs, each one's output, results.txt with a line for
# every law (PASS, FAIL, or STOPPED with the reason) and for every program
# that did not compile (COMPILE), skips.txt with every case skipped and why,
# and times.txt with the seconds each program took to compile and to run.
# The environment of the programs chooses how the laws run (Check.laws):
# RUNE_PROPERTY_DEEP=1 for the deep mode, RUNE_PROPERTY_ONLY=LABEL for one
# law, RUNE_PROPERTY_REPLAY=TOKEN for one case. It is not part of `make check`
# until every law holds (D12). Override the tools with RUNE=, RUNEVM= and
# RUNEDOC=.
set -u
cd "$(dirname "$0")/../.."
top=$(pwd)
rune=${RUNE:-bin/rune}
runevm=${RUNEVM:-bin/runevm}
runedoc=${RUNEDOC:-bin/runedoc}
timeout=${LAWS_TIMEOUT:-60}
memory=${LAWS_MEMORY:-4096}
jobs=1
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    -j) jobs=$2; shift 2 ;;
    -*) echo "usage: tests/basis/run-laws.sh [-j N] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
out=tests/out/laws
rm -rf "$out"
mkdir -p "$out/programs"
if ! "$runedoc" --lib lib --library basis --laws "$out/programs" > "$out/runedoc.log" 2>&1; then
  echo "test-laws: runedoc --laws failed (see $out/runedoc.log)"; exit 1
fi

# compile PROGRAM: the bytecode of a program of laws, or a COMPILE line
compile() {
  p=$1
  name=$(basename "$p" .sml)
  o=$out/$name
  start=$(date +%s.%N)
  if "$rune" --library test/property "$p" -o "$o.rbc" > "$o.cerr" 2>&1; then
    echo "$name compile $(echo "$(date +%s.%N) - $start" | bc)" > "$o.ctime"
  else
    echo "COMPILE $name (see $o.cerr)" > "$o.cresult"
  fi
}

# one NAME STRUCTURE: run the laws of program NAME at STRUCTURE (all of them
# for "-") under the memory bound and the watchdog, skipping the cases the
# machine cannot hold, and write their lines
one() {
  name=$1
  st=$2
  o=$out/$name@$st
  if [ "$st" = "-" ]; then at=""; else at=$st; fi
  mid=$(date +%s.%N)
  : > "$o.out"
  : > "$o.skips"
  : > "$o.result"
  last=""
  skips=""
  while :; do
    ( ulimit -v $((memory * 1024))
      RUNE_PROPERTY_CASES=1 RUNE_PROPERTY_AT=$at RUNE_PROPERTY_AFTER=$last RUNE_PROPERTY_SKIP=$skips exec "$runevm" "$out/$name.rbc" ) > "$o.run" 2>&1 &
    pid=$!
    # the watchdog: a case that runs $timeout seconds without the next line
    lines=0
    idle=0
    stopped=0
    while kill -0 $pid 2> /dev/null; do
      sleep 2
      n=$(wc -l < "$o.run")
      if [ "$n" != "$lines" ]; then lines=$n; idle=0; else idle=$((idle + 2)); fi
      if [ $idle -ge "$timeout" ]; then kill $pid 2> /dev/null; stopped=1; break; fi
    done
    wait $pid
    status=$?
    grep -v '^CASE ' "$o.run" >> "$o.out"
    grep -E '^(PASS|FAIL) ' "$o.run" >> "$o.result"
    if grep -q '^laws: ' "$o.run"; then break; fi
    stuck=$(grep '^LAW ' "$o.run" | tail -1 | cut -d' ' -f2)
    if [ -z "$stuck" ]; then echo "STOPPED $name before its first law (status $status)" >> "$o.result"; break; fi
    if [ $stopped -eq 1 ]; then why="after ${timeout}s"; else why=$(grep -v '^\(LAW\|CASE\|PASS\|FAIL\|  \)' "$o.run" | tail -1); fi
    # the case the machine could not hold: the last one of the law it was in
    case=$(sed -n "/^LAW $(echo "$stuck" | sed 's/[][\/.^$*]/\\&/g')\$/,\$p" "$o.run" | grep '^CASE ' | tail -1 | cut -d' ' -f2)
    count=$(echo "$skips" | tr ' ' '\n' | grep -c "^$stuck:")
    if [ -n "$case" ] && [ "$count" -lt 10 ]; then
      echo "SKIPPED $stuck case $case: $why" >> "$o.skips"
      skips="$skips $stuck:$case"
      # run the law again, after the one before it in this run
      prev=$(grep '^LAW ' "$o.run" | tail -2 | head -1 | cut -d' ' -f2)
      [ "$prev" != "$stuck" ] && last=$prev
    else
      echo "STOPPED $stuck $why${case:+ (the $((count + 1))th case it could not finish)}" >> "$o.result"
      last=$stuck
    fi
  done
  stop=$(date +%s.%N)
  echo "$name@$st run $(echo "$stop - $mid" | bc)" > "$o.time"
}

programs=$(ls "$out/programs"/*.sml | grep -- "$filter")
export out rune runevm timeout memory top
# every program compiled, then its laws run a structure at a time, so that
# the programs with many structures spread over the jobs
# shellcheck disable=SC2016
echo "$programs" | xargs -P "$jobs" -I{} sh -c "$(sed -n '/^compile() {$/,/^}$/p' "$0"); compile {}"
for p in $programs; do
  name=$(basename "$p" .sml)
  [ -f "$out/$name.rbc" ] || continue
  sts=$(grep -o '^  ("[^"]*"' "$p" | grep -o '@[^"]*' | sort -u | cut -c2-)
  if [ -z "$sts" ] || grep -q '^  ("[^"@]*",' "$p"; then echo "$name -"; else for st in $sts; do echo "$name $st"; done; fi
done > "$out/jobs.txt"
# shellcheck disable=SC2016
xargs -P "$jobs" -L 1 sh -c "$(sed -n '/^one() {$/,/^}$/p' "$0"); one \"\$0\" \"\$1\"" < "$out/jobs.txt"

cat "$out"/*.cresult > "$out/compile.txt" 2> /dev/null || : > "$out/compile.txt"
cat "$out/compile.txt" "$out"/*.result > "$out/results.txt"
cat "$out"/*.ctime "$out"/*.time > "$out/times.txt"
cat "$out"/*.skips > "$out/skips.txt" 2> /dev/null || : > "$out/skips.txt"
laws=$(grep -c '^\(PASS\|FAIL\|STOPPED\) ' "$out/results.txt")
passed=$(grep -c '^PASS ' "$out/results.txt")
failed=$(grep -c '^FAIL ' "$out/results.txt")
gaveup=$(grep -c '^FAIL .*: gave up after' "$out/results.txt")
stopped=$(grep -c '^STOPPED ' "$out/results.txt")
broken=$(grep -c '^COMPILE ' "$out/results.txt")
skippedcases=$(wc -l < "$out/skips.txt")
echo "test-laws: $laws laws at their structures, $passed pass, $failed fail ($gaveup of them gave up on their conditions), $stopped stopped; $skippedcases cases skipped; $broken programs did not compile (see $out/results.txt)"
[ "$failed" -eq 0 ] && [ "$stopped" -eq 0 ] && [ "$broken" -eq 0 ]
