#!/bin/sh
# Run MLton's regression programs (github.com/MLton/mlton, regression/) as an
# external conformance corpus:
#   tests/external/run-mlton.sh [--rune BIN] [--vm BIN] [-j N] DIR
# Every DIR/<name>.sml that has a DIR/<name>.ok is compiled, run with a
# 20-second limit, and its stdout compared with the .ok file. Programs listed
# in tests/external/mlton-skip.txt (one name per line, with a reason after
# a space) are skipped: they need Basis Library parts Rune does not have, or
# MLton-specific behaviour. Prints one line per program and a summary; exits
# 1 if a program not on the skip list fails.
set -u
rune=bin/rune
vm=bin/runevm
jobs=$(sh scripts/ncpus.sh 2>/dev/null || echo 4)
dir=""
while [ $# -gt 0 ]; do
  case $1 in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --one) shift; one=$1; shift; dir=$1; shift; break ;;
    *) dir=$1; shift ;;
  esac
done
[ -n "$dir" ] || { echo "usage: $0 [--rune BIN] [--vm BIN] [-j N] DIR" >&2; exit 2; }
out=tests/out/external
mkdir -p "$out"
outabs=$(cd "$out" && pwd)
vmabs=$(cd "$(dirname "$vm")" && pwd)/$(basename "$vm")
skip=tests/external/mlton-skip.txt

run_one() {
  name=$1
  src=$dir/$name.sml
  if [ -f "$skip" ] && grep -q "^$name\( \|$\)" "$skip"; then
    echo "SKIP $name: $(grep "^$name\( \|$\)" "$skip" | sed "s/^$name *//")"
    return
  fi
  if ! "$rune" --no-warnings "$src" -o "$out/$name.rbc" 2> "$out/$name.cerr"; then
    echo "COMPILE $name: $(head -1 "$out/$name.cerr" | sed 's/^[^ ]* error: //')"
    return
  fi
  # run inside a scratch directory: some programs write files where they run
  mkdir -p "$out/$name.dir"
  (cd "$out/$name.dir" && timeout 20 "$vmabs" "$outabs/$name.rbc" > "$outabs/$name.stdout" 2> "$outabs/$name.stderr" < /dev/null)
  code=$?
  if [ $code = 124 ]; then echo "TIMEOUT $name"; return; fi
  # MLton's harness records an uncaught exception and a nonzero exit in the
  # expected output; reproduce that format from runevm's stderr and status.
  if [ $code != 0 ]; then
    sed -n 's/^runevm: uncaught exception \(.*\)$/unhandled exception: \1/p' "$out/$name.stderr" >> "$out/$name.stdout"
    echo "Nonzero exit status." >> "$out/$name.stdout"
  fi
  if cmp -s "$out/$name.stdout" "$dir/$name.ok"; then echo "PASS $name"
  elif [ $code != 0 ]; then echo "RUNTIME $name: $(head -1 "$out/$name.stderr")"
  else echo "OUTPUT $name"
  fi
}

if [ "${one:-}" ]; then run_one "$one" > "$out/$one.result"; exit 0; fi

names=$(for f in "$dir"/*.sml; do n=$(basename "$f" .sml); [ -f "$dir/$n.ok" ] && echo "$n"; done)
echo "$names" | xargs -P "$jobs" -I{} sh "$0" --rune "$rune" --vm "$vm" --one {} "$dir"
pass=0; fail=0; skipped=0
for n in $names; do
  r=$(cat "$out/$n.result")
  echo "$r"
  case $r in PASS*) pass=$((pass+1)) ;; SKIP*) skipped=$((skipped+1)) ;; *) fail=$((fail+1)) ;; esac
done
echo "external: passed $pass, failed $fail, skipped $skipped"
[ $fail = 0 ]
