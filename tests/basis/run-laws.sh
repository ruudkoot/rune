#!/bin/sh
# The laws of the Basis Library's documentation, run (docs/plans/quickcheck.md,
# M8, D9 and D13).
#   tests/basis/run-laws.sh [-j N] [FILTER]
# `runedoc --laws` writes a program for each signature with a law, holding
# every law at every structure that implements the signature. Each program
# whose name contains FILTER is compiled with `rune --library test/property`
# and run with at most $LAWS_MEMORY megabytes (default 4096) under a watchdog
# that stops it when a law has run $LAWS_TIMEOUT seconds (default 120) without
# the next one starting. A run the watchdog stops, or that
# dies, names the law it was in, its last `LAW` line, and is started again
# after that law (RUNE_PROPERTY_AFTER), so that every law has a result. Past
# the memory bound an allocation raises `Size`, which a law reports as an
# outcome. In tests/out/laws: the programs, each one's output, and
# results.txt with a line for every law (PASS, FAIL, or STOPPED with the
# reason) and for every program that did not compile (COMPILE), and
# times.txt with the seconds each program took to compile and to run. The
# environment of the programs chooses how the laws run (Check.laws):
# RUNE_PROPERTY_DEEP=1 for the deep mode, RUNE_PROPERTY_ONLY=LABEL for one
# law, RUNE_PROPERTY_REPLAY=TOKEN for one case. It is not part of `make
# check` until every law holds (D12). Override the tools with RUNE=, RUNEVM=
# and RUNEDOC=.
set -u
cd "$(dirname "$0")/../.."
top=$(pwd)
rune=${RUNE:-bin/rune}
runevm=${RUNEVM:-bin/runevm}
runedoc=${RUNEDOC:-bin/runedoc}
timeout=${LAWS_TIMEOUT:-120}
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

# one program: compile, run under the watchdog, and write its lines
one() {
  p=$1
  name=$(basename "$p" .sml)
  o=$out/$name
  start=$(date +%s.%N)
  if ! "$rune" --library test/property "$p" -o "$o.rbc" > "$o.cerr" 2>&1; then
    echo "COMPILE $name (see $o.cerr)" > "$o.result"
    echo "$name compile $(echo "$(date +%s.%N) - $start" | bc) run -" > "$o.time"
    return
  fi
  mid=$(date +%s.%N)
  : > "$o.out"
  : > "$o.result"
  last=""
  while :; do
    ( ulimit -v $((memory * 1024)); RUNE_PROPERTY_AFTER=$last exec "$runevm" "$o.rbc" ) > "$o.run" 2>&1 &
    pid=$!
    # the watchdog: the laws started so far, and how long since the last
    seen=0
    idle=0
    stopped=0
    while kill -0 $pid 2> /dev/null; do
      sleep 2
      n=$(grep -c '^LAW ' "$o.run")
      if [ "$n" != "$seen" ]; then seen=$n; idle=0; else idle=$((idle + 2)); fi
      if [ $idle -ge "$timeout" ]; then kill $pid 2> /dev/null; stopped=1; break; fi
    done
    wait $pid
    status=$?
    cat "$o.run" >> "$o.out"
    grep -E '^(PASS|FAIL) ' "$o.run" >> "$o.result"
    if grep -q '^laws: ' "$o.run"; then break; fi
    stuck=$(grep '^LAW ' "$o.run" | tail -1 | cut -d' ' -f2)
    if [ -z "$stuck" ]; then echo "STOPPED $name before its first law (status $status)" >> "$o.result"; break; fi
    if [ $stopped -eq 1 ]; then why="after ${timeout}s"; else why="with status $status: $(grep -v '^\(LAW\|PASS\|FAIL\|  \)' "$o.run" | tail -1)"; fi
    echo "STOPPED $stuck $why" >> "$o.result"
    last=$stuck
  done
  stop=$(date +%s.%N)
  echo "$name compile $(echo "$mid - $start" | bc) run $(echo "$stop - $mid" | bc)" > "$o.time"
}

programs=$(ls "$out/programs"/*.sml | grep -- "$filter")
if [ "$jobs" -gt 1 ]; then
  export out rune runevm timeout memory top
  # shellcheck disable=SC2016
  echo "$programs" | xargs -P "$jobs" -I{} sh -c "$(sed -n '/^one() {$/,/^}$/p' "$0"); one {}"
else
  for p in $programs; do one "$p"; done
fi

cat "$out"/*.result > "$out/results.txt"
cat "$out"/*.time > "$out/times.txt"
laws=$(grep -c '^\(PASS\|FAIL\|STOPPED\) ' "$out/results.txt")
passed=$(grep -c '^PASS ' "$out/results.txt")
failed=$(grep -c '^FAIL ' "$out/results.txt")
gaveup=$(grep -c '^FAIL .*: gave up after' "$out/results.txt")
stopped=$(grep -c '^STOPPED ' "$out/results.txt")
broken=$(grep -c '^COMPILE ' "$out/results.txt")
echo "test-laws: $laws laws at their structures, $passed pass, $failed fail ($gaveup of them gave up on their conditions), $stopped stopped; $broken programs did not compile (see $out/results.txt)"
[ "$failed" -eq 0 ] && [ "$stopped" -eq 0 ] && [ "$broken" -eq 0 ]
