#!/bin/sh
# Programs of several files, compiled whole and a unit per file (rune
# --units; docs/units.md). Each directory here is a program, its files in
# the order its `files` names them. Every build -- whole and in units, for
# the register bytecode on bin/runevm and the stack bytecode on
# bin/runevm-stack -- is compiled and run, and what it did is compared with
# DIR/expected: the compiler's standard error and status, then, where it
# compiled, the program's standard output, standard error and status. A
# directory with a whole.expected wants that of its whole builds instead:
# what the two builds may differ in (docs/units.md).
#   tests/units/run.sh [--rune BIN]
set -u
cd "$(dirname "$0")/../.."
rune=bin/rune
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    *) echo "usage: tests/units/run.sh [--rune BIN]" >&2; exit 2 ;;
  esac
done
out=tests/out/units-suite
mkdir -p "$out"
fails=0
n=0
for dir in tests/units/*/; do
  dir=${dir%/}
  name=$(basename "$dir")
  files=$(sed "s|^|$dir/|" "$dir/files" | tr '\n' ' ')
  for build in whole units; do
    for target in registers stack; do
      case $target in registers) vm=bin/runevm ;; stack) vm=bin/runevm-stack ;; esac
      flags="--target=$target"
      [ $build = units ] && flags="$flags --units"
      result=$out/$name.$build.$target
      # shellcheck disable=SC2086
      "$rune" $flags $files -o "$result.rbc" > /dev/null 2> "$result.cerr"
      status=$?
      {
        cat "$result.cerr"
        echo "compile: $status"
        if [ $status = 0 ]; then
          "$vm" "$result.rbc" > "$result.out" 2> "$result.err"
          code=$?
          cat "$result.out" "$result.err"
          echo "run: $code"
        fi
      } > "$result.got"
      want=$dir/expected
      [ $build = whole ] && [ -f "$dir/whole.expected" ] && want=$dir/whole.expected
      n=$((n + 1))
      if ! cmp -s "$want" "$result.got"; then
        echo "FAIL units-suite.$name: $build $target (diff $want $result.got)"
        fails=$((fails + 1))
      fi
    done
  done
done
if [ $fails -gt 0 ]; then
  echo "units suite: $fails of $n builds fail"
  exit 1
fi
echo "units suite: $n builds as expected"
