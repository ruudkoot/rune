#!/bin/sh
# The tests of the intermediate representations (docs/ir.md). Each
# tests/ir/NAME.sml is compiled without the Basis Library, and each
# tests/ir/NAME.mid read as a Mid program (--read-mid), with the lint of
# every pass on and Mid's text checked against itself (--mid-roundtrip). Its
# first line says what to look at:
#   (* dump: --dump-after=PASS *)  the dump, compared with NAME.expected,
#                                  which is reviewed line by line like any
#                                  .expected file;
#   (* fail: MESSAGE *)            that the compiler stops with MESSAGE,
#                                  for a program a lint must refuse.
#   tests/ir/run-ir-tests.sh [--rune BIN] [--update] [FILTER]
set -u
cd "$(dirname "$0")/../.."
rune=bin/rune
update=0
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --update) update=1; shift ;;
    *) filter=$1; shift ;;
  esac
done
out=tests/out/ir
mkdir -p "$out"
pass=0
fail=0
for src in tests/ir/*.sml tests/ir/*.mid; do
  [ -f "$src" ] || continue
  name=$(basename "$src"); name=${name%.*}
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  case "$src" in
    *.mid) input="--read-mid $src" ;;
    *) input="--no-prelude -o $out/$name.rbc $src" ;;
  esac
  dump=$(sed -n '1s/^(\* dump: \(.*\) \*)$/\1/p' "$src")
  refusal=$(sed -n '1s/^(\* fail: \(.*\) \*)$/\1/p' "$src")
  if [ -n "$refusal" ]; then
    # shellcheck disable=SC2086
    if "$rune" --lint --mid-roundtrip $input > "$out/$name.out" 2> "$out/$name.err"; then
      echo "FAIL ir.$name: accepted, where it should stop with: $refusal"; fail=$((fail + 1))
    elif grep -qF -- "$refusal" "$out/$name.err"; then pass=$((pass + 1))
    else echo "FAIL ir.$name: stopped with: $(head -1 "$out/$name.err")"; fail=$((fail + 1)); fi
    continue
  fi
  if [ -z "$dump" ]; then echo "FAIL ir.$name: its first line names no dump"; fail=$((fail + 1)); continue; fi
  # shellcheck disable=SC2086
  if ! "$rune" --lint --mid-roundtrip $dump $input > "$out/$name.out" 2> "$out/$name.err"; then
    echo "FAIL ir.$name: rune failed: $(head -1 "$out/$name.err")"; fail=$((fail + 1)); continue
  fi
  if [ $update = 1 ]; then cp "$out/$name.out" "tests/ir/$name.expected"; fi
  if cmp -s "$out/$name.out" "tests/ir/$name.expected"; then pass=$((pass + 1))
  else echo "FAIL ir.$name: the dump differs from tests/ir/$name.expected"; diff "tests/ir/$name.expected" "$out/$name.out" | head -20; fail=$((fail + 1)); fi
done
echo "ir: passed $pass, failed $fail"
[ $fail = 0 ]
