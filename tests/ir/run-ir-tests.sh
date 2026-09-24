#!/bin/sh
# The tests of the intermediate representations (docs/ir.md): each
# tests/ir/NAME.sml is compiled without the Basis Library, with the lint of
# every pass on, and what its first line asks to be dumped (a comment
# `(* dump: --dump-after=PASS *)`) is compared with NAME.expected, which is
# reviewed line by line like any .expected file.
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
for src in tests/ir/*.sml; do
  name=$(basename "$src" .sml)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  dump=$(sed -n '1s/^(\* dump: \(.*\) \*)$/\1/p' "$src")
  if [ -z "$dump" ]; then echo "FAIL ir.$name: its first line names no dump"; fail=$((fail + 1)); continue; fi
  # shellcheck disable=SC2086
  if ! "$rune" --no-prelude --lint $dump -o "$out/$name.rbc" "$src" > "$out/$name.out" 2> "$out/$name.err"; then
    echo "FAIL ir.$name: rune failed: $(head -1 "$out/$name.err")"; fail=$((fail + 1)); continue
  fi
  if [ $update = 1 ]; then cp "$out/$name.out" "tests/ir/$name.expected"; fi
  if cmp -s "$out/$name.out" "tests/ir/$name.expected"; then pass=$((pass + 1))
  else echo "FAIL ir.$name: the dump differs from tests/ir/$name.expected"; diff "tests/ir/$name.expected" "$out/$name.out" | head -20; fail=$((fail + 1)); fi
done
echo "ir: passed $pass, failed $fail"
[ $fail = 0 ]
