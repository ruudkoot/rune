#!/bin/sh
# The REPL's transcripts (docs/repl.md): each NAME.in is typed to
# bin/rune-repl, whose standard output and standard error together must be
# NAME.expected, written by hand or reviewed line by line. A transcript with
# a line `#!interrupt after TEXT` is typed by tests/repl/drive.py, which
# sends the REPL SIGINT there, once it has written TEXT. Where NAME.then is
# there too, the transcript saved the session to $RUNE_REPL_OUT/NAME.img
# (Runtime.save), and NAME.then is typed to the world restored from it,
# which must write NAME.then.expected.
# --vm-opts OPTS runs the REPL on bin/runevm OPTS (a mode of the JIT, a
# collector) rather than as bin/rune-repl does; --vm VM on another VM of the
# register bytecode (bin/runevm-asan), which restores the same image.
#   tests/repl/run.sh [--vm VM] [--vm-opts OPTS] [--out DIR] [FILTER]
set -u
cd "$(dirname "$0")/../.."
vm=bin/runevm
vmopts=""
filter=""
out=tests/out/repl
while [ $# -gt 0 ]; do
  case "$1" in
    --vm) vm=$2; shift 2 ;;
    --vm-opts) vmopts=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    *) filter=$1; shift ;;
  esac
done
# shellcheck disable=SC2086
repl() { "$vm" $vmopts --heap-size 67108864 --restore bin/rune-repl.img --; }
mkdir -p "$out"
RUNE_REPL_OUT=$out
export RUNE_REPL_OUT
pass=0
fail=0
for t in tests/repl/*.in; do
  name=$(basename "$t" .in)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  if grep -q '^#!interrupt ' "$t"; then
    # shellcheck disable=SC2086
    python3 tests/repl/drive.py "$out/$name.out" "$vm" $vmopts --heap-size 67108864 --restore bin/rune-repl.img -- < "$t"
  else
    repl < "$t" > "$out/$name.out" 2>&1
  fi
  if ! cmp -s "tests/repl/$name.expected" "$out/$name.out"; then
    echo "FAIL repl.$name (diff tests/repl/$name.expected $out/$name.out)"
    fail=$((fail + 1))
    continue
  fi
  if [ -f "tests/repl/$name.then" ]; then
    # shellcheck disable=SC2086
    "$vm" $vmopts --heap-size 67108864 --restore "$out/$name.img" -- < "tests/repl/$name.then" > "$out/$name.then.out" 2>&1
    if ! cmp -s "tests/repl/$name.then.expected" "$out/$name.then.out"; then
      echo "FAIL repl.$name, restored (diff tests/repl/$name.then.expected $out/$name.then.out)"
      fail=$((fail + 1))
      continue
    fi
  fi
  pass=$((pass + 1))
done
echo "repl ($vm $vmopts): passed $pass, failed $fail"
[ $fail = 0 ]
