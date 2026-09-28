#!/bin/sh
# The adequacy of the laws (docs/plans/quickcheck.md, M9): mutants of the
# Basis Library's own sources, run against the laws of its documentation.
#   tests/basis/run-mutants.sh [-j N] [-n PER_FILE] [FILTER]
# Each target is a file of lib/basis and the structure whose laws hold it;
# tools/mutate/mutate.sml lists the file's mutation sites, of which at most
# PER_FILE (default 20), evenly spaced, are tried. A mutant is the Basis
# Library with that one change, beside lib/test/property and lib/random:
# the programs of `runedoc --laws` that hold a law at the structure are
# compiled against it and run with RUNE_PROPERTY_AT, under the memory bound
# and the watchdog of run-laws.sh. A mutant is KILLED when a law that passes
# at the structure on the Basis Library does not pass on the mutant (it
# fails, is stopped, or never runs), SURVIVED when every such law passes, and
# STILLBORN when a program does not compile. In
# tests/out/mutants: results.txt, a line for each mutant with the laws that
# killed it, and summary.txt, the counts of each target.
# Override the tools with RUNE=, RUNEVM= and RUNEDOC=.
set -u
cd "$(dirname "$0")/../.."
top=$(pwd)
rune=${RUNE:-bin/rune}
runevm=${RUNEVM:-bin/runevm}
runedoc=${RUNEDOC:-bin/runedoc}
timeout=${LAWS_TIMEOUT:-30}
memory=${LAWS_MEMORY:-4096}
jobs=1
per=20
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    -j) jobs=$2; shift 2 ;;
    -n) per=$2; shift 2 ;;
    -*) echo "usage: tests/basis/run-mutants.sh [-j N] [-n PER_FILE] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
targets="list:List listpair:ListPair char:Char string:String substring:Substring int:Int intn_fn:Int8 intinf:IntInf
word:Word wordn_fn:Word8 array:Array arrayslice:ArraySlice array2:Array2 byte:Byte"
out=tests/out/mutants
rm -rf "$out"
mkdir -p "$out/programs" "$out/runs"
"$runedoc" --lib lib --library basis --laws "$out/programs" > "$out/runedoc.log" 2>&1 ||
  { echo "test-mutants: runedoc --laws failed (see $out/runedoc.log)"; exit 1; }
"$rune" tools/mutate/mutate.sml -o "$out/mutate.rbc" > "$out/mutate.cerr" 2>&1 ||
  { echo "test-mutants: tools/mutate/mutate.sml does not compile (see $out/mutate.cerr)"; exit 1; }

# a library root beside lib: basis from DIR, the rest from lib
root() {
  dir=$1
  mkdir -p "$dir/test"
  ln -s "$top/lib/random" "$dir/random"
  ln -s "$top/lib/test/property" "$dir/test/property"
}

# run LIB STRUCTURE NAME: compile the programs that hold a law at STRUCTURE
# against LIB and run them; the result lines go to $out/runs/NAME.result,
# and the status is 1 when a program does not compile
run() {
  lib=$1; st=$2; name=$3
  o=$out/runs/$name
  : > "$o.result"
  for p in $(grep -l "@$st\"" "$out/programs"/*.sml); do
    b=$o.$(basename "$p" .sml)
    "$rune" --lib "$lib" --library test/property "$p" -o "$b.rbc" > "$b.cerr" 2>&1 || return 1
    last=""
    while :; do
      ( ulimit -v $((memory * 1024)); RUNE_PROPERTY_AT=$st RUNE_PROPERTY_AFTER=$last exec "$runevm" "$b.rbc" ) > "$b.run" 2>&1 &
      pid=$!
      seen=0; idle=0; stopped=0
      while kill -0 $pid 2> /dev/null; do
        sleep 1
        n=$(grep -c '^LAW ' "$b.run")
        if [ "$n" != "$seen" ]; then seen=$n; idle=0; else idle=$((idle + 1)); fi
        if [ $idle -ge "$timeout" ]; then kill $pid 2> /dev/null; stopped=1; break; fi
      done
      wait $pid
      grep -E '^(PASS|FAIL) ' "$b.run" >> "$o.result"
      if grep -q '^laws: ' "$b.run"; then break; fi
      stuck=$(grep '^LAW ' "$b.run" | tail -1 | cut -d' ' -f2)
      [ -z "$stuck" ] && break
      echo "STOPPED $stuck" >> "$o.result"
      last=$stuck
    done
    rm -f "$b.rbc"
  done
  return 0
}

# one mutant: FILE STRUCTURE K
mutant() {
  f=$1; st=$2; k=$3
  name=$f-$k
  d=$out/libs/$name
  mkdir -p "$d/basis"
  for x in "$top"/lib/basis/*; do ln -s "$x" "$d/basis/"; done
  rm "$d/basis/$f.sml"
  "$runevm" "$out/mutate.rbc" "lib/basis/$f.sml" "$k" > "$d/basis/$f.sml"
  root "$d"
  site=$(sed -n "${k}p" "$out/sites-$f.txt" | cut -d' ' -f2-)
  if ! run "$d" "$st" "$name"; then
    echo "STILLBORN $f $k $site"
  else
    # a law that passes on the Basis Library and does not pass here, however
    # it did not: it failed, was stopped, or never ran (the mutant may break
    # the tester itself, which uses the Basis Library)
    grep '^PASS ' "$out/runs/$name.result" | awk '{print $2}' | sed 's/:$//' | sort -u > "$out/runs/$name.pass"
    killers=$(comm -23 "$out/base-$st.pass" "$out/runs/$name.pass" | tr '\n' ' ')
    if [ -n "$killers" ]; then echo "KILLED $f $k $site by $killers"; else echo "SURVIVED $f $k $site"; fi
  fi
  rm -rf "$d"
}

for t in $targets; do
  f=${t%%:*}; st=${t#*:}
  case "$f" in *"$filter"*) ;; *) continue ;; esac
  # the baseline: the laws that pass at the structure on the Basis Library
  # (made once: a second ln -s into an existing link would land in lib)
  if [ ! -e "$out/base-lib" ]; then
    root "$out/base-lib"
    ln -s "$top/lib/basis" "$out/base-lib/basis"
  fi
  run "$out/base-lib" "$st" "base-$st"
  grep '^PASS ' "$out/runs/base-$st.result" | awk '{print $2}' | sed 's/:$//' | sort -u > "$out/base-$st.pass"
  "$runevm" "$out/mutate.rbc" "lib/basis/$f.sml" > "$out/sites-$f.txt"
  total=$(wc -l < "$out/sites-$f.txt")
  step=$(( (total + per - 1) / per ))
  [ "$step" -lt 1 ] && step=1
  k=1
  while [ "$k" -le "$total" ]; do echo "$f $st $k"; k=$((k + step)); done
done > "$out/todo.txt"

export out top rune runevm timeout memory
# shellcheck disable=SC2016
xargs -P "$jobs" -L 1 sh -c "$(sed -n '/^root() {$/,/^}$/p; /^run() {$/,/^}$/p; /^mutant() {$/,/^}$/p' "$0"); mutant \"\$0\" \"\$1\" \"\$2\"" \
  < "$out/todo.txt" > "$out/results.txt"

sort -o "$out/results.txt" "$out/results.txt"
for t in $targets; do
  f=${t%%:*}; st=${t#*:}
  case "$f" in *"$filter"*) ;; *) continue ;; esac
  all=$(grep -c " $f " "$out/results.txt")
  killed=$(grep -c "^KILLED $f " "$out/results.txt")
  survived=$(grep -c "^SURVIVED $f " "$out/results.txt")
  still=$(grep -c "^STILLBORN $f " "$out/results.txt")
  echo "$f ($st, $(wc -l < "$out/base-$st.pass") laws pass): $killed of $((all - still)) mutants killed, $survived survived, $still stillborn"
done | tee "$out/summary.txt"
