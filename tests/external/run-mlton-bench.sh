#!/bin/sh
# MLton's benchmark programs (github.com/MLton/mlton, benchmark/tests) as a
# workload set with exact counts (docs/plans/heap-layout.md, M1):
#   tests/external/run-mlton-bench.sh [--dir DIR] [--rune BIN] [--vm BIN] [--vm-opts OPTS]
#       [--timeout S] [--all] [--update] [--prepare] [-j N] [FILTER...]
# DIR is /home/ruud/reference/mlton/benchmark/tests unless --dir or
# $MLTON_BENCH says otherwise; the programs are read from there, never
# copied into the tree. Every line `NAME N BYTES OBJECTS` of
# tests/perf/mlton-bench.txt whose NAME contains a FILTER (every line when
# there is none) is one program:
#   tests/out/mlton-bench/NAME.sml = tests/external/mlton-bench/NAME.shim.sml
#   (when it exists), then DIR/NAME.sml passed through NAME.sed (when it
#   exists), then `val _ = Main.doit N` unless NAME.nowrap exists; compiled
#   by --rune (bin/rune-new: the register bytecode) to NAME.rbc, and run in
#   tests/out/mlton-bench (DIR/DATA copied there, fxp's input generated) by
#   --vm (bin/runevm-new) with --count and OPTS, the words of NAME.args as
#   its arguments, standard input from /dev/null, under --timeout (600 s).
# PASS when the bytes and objects of --count equal the file's (the count
# oracle of docs/testing.md), COUNT when they differ, COMPILE, RUNTIME and
# TIMEOUT otherwise; SKIP for a program whose line has `-` for N, and for
# one recorded above 2 GB unless --all. --update rewrites the file's bytes
# and objects from the runs, for a deliberate change. --prepare stops after
# the sources and the bytecode (scripts/census.sh uses it). Exits 1 if a
# program fails; SKIPs do not count.
set -u
dir=${MLTON_BENCH:-/home/ruud/reference/mlton/benchmark/tests}
rune=bin/rune-new
vm=bin/runevm-new
vmopts=""
tmo=600
all=0
update=0
prepare=0
jobs=$(sh scripts/ncpus.sh 2>/dev/null || echo 4)
one=""
filters=""
while [ $# -gt 0 ]; do
  case $1 in
    --dir) dir=$2; shift 2 ;;
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    --vm-opts) vmopts="$vmopts $2"; shift 2 ;;
    --timeout) tmo=$2; shift 2 ;;
    --all) all=1; shift ;;
    --update) update=1; shift ;;
    --prepare) prepare=1; shift ;;
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    -*) echo "usage: tests/external/run-mlton-bench.sh [--dir DIR] [--rune BIN] [--vm BIN] [--vm-opts OPTS] [--timeout S] [--all] [--update] [--prepare] [-j N] [FILTER...]" >&2; exit 2 ;;
    *) filters="$filters $1"; shift ;;
  esac
done
cd "$(dirname "$0")/../.."
root=$(pwd)
table=tests/perf/mlton-bench.txt
shims=tests/external/mlton-bench
out=tests/out/mlton-bench
mkdir -p "$out"
[ -d "$dir" ] || { echo "run-mlton-bench: no $dir (MLton's benchmark/tests)" >&2; exit 2; }
case "$rune" in /*) ;; *) rune=$root/$rune ;; esac
case "$vm" in /*) ;; *) vm=$root/$vm ;; esac
command -v timeout > /dev/null 2>&1 || tmo=""

# line NAME: the program's line of the table
line() { grep "^$1 " "$table" | head -1; }

# prepare NAME N: the source and the bytecode; prints a COMPILE line on failure
prepare_one() {
  name=$1; n=$2
  src=$out/$name.sml
  {
    [ -f "$shims/$name.shim.sml" ] && cat "$shims/$name.shim.sml"
    if [ -f "$shims/$name.sed" ]; then sed -f "$shims/$name.sed" "$dir/$name.sml"; else cat "$dir/$name.sml"; fi
    [ -f "$shims/$name.nowrap" ] || printf '\nval _ = Main.doit %s\n' "$n"
  } > "$src"
  [ -f "$shims/$name.args" ] && cp "$shims/$name.args" "$out/$name.args"
  if ! "$rune" "$src" -o "$out/$name.rbc" 2> "$out/$name.cerr"; then
    echo "COMPILE $name: $(head -1 "$out/$name.cerr" | sed 's/^[^ ]* error: //')"; return 1
  fi
  return 0
}

run_one() {
  name=$1
  set -- $(line "$name")
  n=${2:-}; want_bytes=${3:-}; want_objects=${4:-}
  [ -n "$n" ] || { echo "SKIP $name: not in $table"; return; }
  if [ "$n" = "-" ]; then echo "SKIP $name: $(line "$name" | sed 's/^[^#]*# *//')"; return; fi
  if [ $all = 0 ] && [ "$want_bytes" != "-" ] && [ "$want_bytes" -gt 2000000000 ] 2> /dev/null; then
    echo "SKIP $name: $(awk "BEGIN { printf \"%.0f\", $want_bytes / 1e9 }") GB at n=$n; --all runs it"; return
  fi
  prepare_one "$name" "$n" || return
  [ $prepare = 1 ] && { echo "PREPARED $name"; return; }
  args=""; [ -f "$out/$name.args" ] && args=$(cat "$out/$name.args")
  # shellcheck disable=SC2086
  (cd "$out" && ${tmo:+timeout $tmo} "$vm" --count $vmopts "$name.rbc" $args < /dev/null > "$name.stdout" 2> "$name.stderr")
  code=$?
  if [ $code = 124 ]; then echo "TIMEOUT $name: ${tmo} s"; return; fi
  got=$(sed -n 's/^runevm: count: [0-9]* instructions, \([0-9]*\) bytes, \([0-9]*\) objects$/\1 \2/p' "$out/$name.stderr" | tail -1)
  if [ $code != 0 ] || [ -z "$got" ]; then echo "RUNTIME $name: exit $code: $(grep -v '^runevm: count' "$out/$name.stderr" | head -1)"; return; fi
  echo "$got" > "$out/$name.count"
  if [ "$got" = "$want_bytes $want_objects" ]; then echo "PASS $name: $got"
  else echo "COUNT $name: $got, where $table says $want_bytes $want_objects"; fi
}

if [ -n "$one" ]; then run_one "$one" > "$out/$one.result"; exit 0; fi

# the DATA directory the programs read, and fxp's input
[ -d "$out/DATA" ] || cp -r "$dir/DATA" "$out/DATA"
[ -s "$out/fxp-input.xml" ] || sh "$shims/gen-fxp-input.sh" > "$out/fxp-input.xml"

names=""
for name in $(grep -v -E '^[[:space:]]*(#|$)' "$table" | awk '{ print $1 }'); do
  if [ -z "$filters" ]; then names="$names $name"; continue; fi
  for f in $filters; do case "$name" in *"$f"*) names="$names $name"; break ;; esac; done
done
[ -n "$names" ] || { echo "run-mlton-bench: no program matches$filters" >&2; exit 2; }
for name in $names; do rm -f "$out/$name.result" "$out/$name.count"; done
echo "$names" | tr ' ' '\n' | grep . | xargs -P "$jobs" -I{} sh "$0" --dir "$dir" --rune "$rune" --vm "$vm" ${vmopts:+--vm-opts "$vmopts"} --timeout "${tmo:-0}" $( [ $all = 1 ] && echo --all ) $( [ $prepare = 1 ] && echo --prepare ) --one {}
pass=0; fail=0; skipped=0
for name in $names; do
  r=$(cat "$out/$name.result" 2> /dev/null || echo "FAIL $name: no result")
  echo "$r"
  case $r in PASS*|PREPARED*) pass=$((pass+1)) ;; SKIP*) skipped=$((skipped+1)) ;; COUNT*) [ $update = 1 ] && pass=$((pass+1)) || fail=$((fail+1)) ;; *) fail=$((fail+1)) ;; esac
done
if [ $update = 1 ]; then
  tmp=$out/mlton-bench.txt.new
  while IFS= read -r l; do
    case "$l" in
      ''|'#'*) echo "$l" ;;
      *) name=${l%% *}
         if [ -s "$out/$name.count" ]; then
           set -- $l; note=""; case "$l" in *'#'*) note=" # ${l#*# }" ;; esac
           echo "$1 $2 $(cat "$out/$name.count")$note"
         else echo "$l"; fi ;;
    esac
  done < "$table" > "$tmp"
  mv "$tmp" "$table"
  echo "mlton-bench: $table updated"
fi
echo "mlton-bench: passed $pass, failed $fail, skipped $skipped"
[ $fail = 0 ]
