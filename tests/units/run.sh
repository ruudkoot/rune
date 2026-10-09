#!/bin/sh
# Programs of several files, compiled whole and a unit per file (rune
# --units; docs/units.md). Each directory here is a program, its files in
# the order its `files` names them. Every build -- whole and in units, for
# the register bytecode on bin/runevm and the stack bytecode on
# bin/runevm-stack -- is compiled and run, and what it did is compared with
# DIR/expected: the compiler's standard error and status, then, where it
# compiled, the program's standard output, standard error and status. A
# directory with a whole.expected wants that of its whole builds instead:
# what the two builds may differ in (docs/units.md). The units build also
# writes its unit files (--emit-units), and tests/units/load.sml, which loads
# each with Runtime.load and runs it, must print the same on standard output
# and exit the same as the units build linked by the compiler (its traces
# have the loader's frames below the program's).
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
for target in registers stack; do
  "$rune" --target=$target tests/units/load.sml -o "$out/load.$target.rbc" ||
    { echo "units suite: tests/units/load.sml does not compile" >&2; exit 1; }
done
for dir in tests/units/*/; do
  dir=${dir%/}
  name=$(basename "$dir")
  files=$(sed "s|^|$dir/|" "$dir/files" | tr '\n' ' ')
  for build in whole units; do
    for target in registers stack; do
      case $target in registers) vm=bin/runevm ;; stack) vm=bin/runevm-stack ;; esac
      flags="--target=$target"
      result=$out/$name.$build.$target
      [ $build = units ] && { rm -rf "$result.files"; flags="$flags --units --emit-units $result.files"; }
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
      # the units loaded one by one into a running program
      if [ $build = units ] && [ $status = 0 ]; then
        # shellcheck disable=SC2046
        "$vm" "$out/load.$target.rbc" $(cat "$result.files/units") > "$result.loaded.out" 2> "$result.loaded.err"
        echo $? > "$result.loaded.code"
        n=$((n + 1))
        if ! cmp -s "$result.out" "$result.loaded.out" || [ "$(cat "$result.loaded.code")" != "$code" ]; then
          echo "FAIL units-suite.$name: loaded $target (diff $result.out $result.loaded.out; status $code and $(cat "$result.loaded.code"); $result.loaded.err)"
          fails=$((fails + 1))
        fi
      fi
    done
  done
done

# ---- the loader's own cases (docs/units.md, Loading), on the unit files
# of twice and across that the builds above wrote: a unit loaded twice, a
# unit shadowed, files that are no unit or are cut short, a unit whose
# imports are not loaded or are of another compile or instruction set, and
# the units loaded into a world that is saved and then restored.
# loaded NAME WANT ARGS...: the VM's output on both streams, its traces
# left out, and its status, are WANT
loaded() {
  lname=$1 lwant=$2
  shift 2
  "$@" > "$out/$lname.out" 2> "$out/$lname.err"
  lcode=$?
  lgot=$(cat "$out/$lname.out"; grep -v '^  in ' "$out/$lname.err"; echo "status $lcode")
  n=$((n + 1))
  if [ "$lgot" != "$(printf "$lwant")" ]; then
    echo "FAIL units-suite.loader.$lname: got"; echo "$lgot"; echo "wanted"; printf "$lwant\n"
    fails=$((fails + 1))
  fi
}
# refused NAME MESSAGE ARGS...: the VM's standard error begins with MESSAGE
# (a stamp of the compile may follow it), and its status is 1
refused() {
  lname=$1 lwant=$2
  shift 2
  "$@" > "$out/$lname.out" 2> "$out/$lname.err"
  lcode=$?
  n=$((n + 1))
  case "$(head -1 "$out/$lname.err")" in
    "$lwant"*) [ $lcode = 1 ] && return ;;
  esac
  echo "FAIL units-suite.loader.$lname: status $lcode, $(head -1 "$out/$lname.err"), wanted $lwant"
  fails=$((fails + 1))
}
for target in registers stack; do
  case $target in registers) vm=bin/runevm; other=stack ;; stack) vm=bin/runevm-stack; other=registers ;; esac
  "$rune" --target=$target tests/units/loadsave.sml -o "$out/loadsave.$target.rbc" ||
    { echo "units suite: tests/units/loadsave.sml does not compile" >&2; exit 1; }
  load=$out/load.$target.rbc
  units=$out/twice.units.$target.files/units
  basis=$(sed '/-a\.rbu$/,$d' "$units" | tr '\n' ' ')
  a=$(grep -e '-a\.rbu$' "$units")
  b=$(grep -e '-b\.rbu$' "$units")
  last=$(sed '1,/-b\.rbu$/d' "$units" | tr '\n' ' ')
  head -c 100 "$a" > "$out/cut.$target.rbu"
  # shellcheck disable=SC2086
  {
    loaded twice.$target "1\n2\nstatus 0" "$vm" "$load" $basis "$a" "$b" "$b" $last
    loaded shadowed.$target "1\n1\nstatus 0" "$vm" "$load" $basis "$a" "$b" "$a" "$b" $last
    loaded not-a-unit.$target "runevm: uncaught exception Fail \"Runtime.link: not a unit of Rune bytecode\"\nstatus 1" \
      "$vm" "$load" $basis tests/units/load.sml
    refused cut-short.$target "runevm: uncaught exception Fail \"Runtime.link: " \
      "$vm" "$load" $basis "$out/cut.$target.rbu"
    refused not-loaded.$target "runevm: uncaught exception Fail \"Runtime.link: the unit names " \
      "$vm" "$load" "$b"
    refused other-compile.$target "runevm: uncaught exception Fail \"Runtime.link: the unit names " \
      "$vm" "$load" $basis "$(grep -e '-b\.rbu$' "$out/across.units.$target.files/units")"
    loaded other-set.$target "runevm: uncaught exception Fail \"Runtime.link: a unit of another instruction set\"\nstatus 1" \
      "$vm" "$load" "$(head -1 "$out/twice.units.$other.files/units")"
    loaded saved.$target "status 0" "$vm" "$out/loadsave.$target.rbc" $basis "$a" --save "$out/loaded.$target.img" "$b" $last
    loaded restored.$target "1\nstatus 0" "$vm" --restore "$out/loaded.$target.img"
  }
done

if [ $fails -gt 0 ]; then
  echo "units suite: $fails of $n builds fail"
  exit 1
fi
echo "units suite: $n builds and loads as expected"
