#!/bin/sh
# The language suite on the Windows VM (`make test-windows`):
#   tests/run-windows.sh [--rune BIN] [--vm BIN] [-j N] [FILTER]
# The compiler and the bytecode are the ordinary ones; only the VM differs,
# so this runs tests/run-tests.sh with --vm bin/runevm.exe and leaves out the
# programs of tests/windows-skip.txt, which name what the system layer of
# Windows does not do (vm/sys_win.c). The file's header lists the reasons;
# a line is "NAME CATEGORY: reason".
#
# Running an .exe needs Windows, or WSL, which starts one for you. Nothing
# else in the tree depends on this: it is not part of make check.
set -u
rune=bin/rune
vm=bin/runevm.exe
jobs=$(sh scripts/ncpus.sh 2>/dev/null || echo 4)
filter=""
while [ $# -gt 0 ]; do
  case $1 in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    -*) echo "usage: $0 [--rune BIN] [--vm BIN] [-j N] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
cd "$(dirname "$0")/.."
[ -x "$vm" ] || { echo "run-windows: $vm is missing (make windows)" >&2; exit 2; }
if ! "$vm" --version > /dev/null 2>&1; then
  echo "run-windows: $vm will not start here; Windows or WSL is needed" >&2
  exit 2
fi

skip=tests/windows-skip.txt
out=tests/out/windows
mkdir -p "$out"
list=$out/tests.txt
ls tests/lang/*.sml | sed 's|tests/lang/||; s|\.sml$||' > "$list"
[ -z "$filter" ] || { grep "$filter" "$list" > "$list.f" && mv "$list.f" "$list"; }

pass=0; fail=0; skipped=0
: > "$out/failures.txt"
while read -r name; do
  if [ -f "$skip" ] && grep -q "^$name " "$skip"; then
    skipped=$((skipped + 1))
    continue
  fi
  base=tests/lang/$name
  [ -f "$base.expected" ] || continue
  if ! "$rune" -o "$out/$name.rbc" "$base.sml" > "$out/$name.log" 2>&1; then
    echo "FAIL $name: compile error: $(head -1 "$out/$name.log")" >> "$out/failures.txt"
    fail=$((fail + 1)); continue
  fi
  # the siblings tests/run-tests.sh knows: arguments, VM options, standard
  # input, the exit status and the standard error
  args=""; [ -f "$base.args" ] && args=$(cat "$base.args")
  vmargs=""; [ -f "$base.vmargs" ] && vmargs=$(cat "$base.vmargs")
  stdin=/dev/null; [ -f "$base.stdin" ] && stdin=$base.stdin
  want=0; [ -f "$base.exitcode" ] && want=$(cat "$base.exitcode")
  # shellcheck disable=SC2086
  "$vm" $vmargs "$out/$name.rbc" $args < "$stdin" > "$out/$name.stdout" 2> "$out/$name.err"
  code=$?
  if [ "$code" != "$want" ]; then
    echo "FAIL $name: exit code $code, expected $want: $(head -1 "$out/$name.err")" >> "$out/failures.txt"
    fail=$((fail + 1)); continue
  fi
  if ! cmp -s "$out/$name.stdout" "$base.expected"; then
    echo "FAIL $name: stdout differs ($(head -1 "$out/$name.err" 2>/dev/null))" >> "$out/failures.txt"
    fail=$((fail + 1)); continue
  fi
  if [ -f "$base.stderr" ] && ! cmp -s "$out/$name.err" "$base.stderr"; then
    echo "FAIL $name: stderr differs" >> "$out/failures.txt"
    fail=$((fail + 1)); continue
  fi
  pass=$((pass + 1))
done < "$list"

[ "$fail" = 0 ] || cat "$out/failures.txt"
echo "windows: passed $pass, failed $fail, skipped $skipped"
[ "$fail" = 0 ]
