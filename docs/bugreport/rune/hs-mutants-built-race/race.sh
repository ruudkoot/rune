#!/bin/sh
# race.sh [DELAY]: run from the root of a tree with bin/rhc.rbc and
# bin/rune-test built. Runs hs-mutant HU07 and, DELAY seconds into it (30 by
# default, while it compares outputs), its built job, hs-mutant-built HU07, in
# one run directory, as the tier does when it runs the two at once. Then says
# what each printed and when it ended.
#
# At haskell98 80792e82d the mutant ends as the built job begins, 1 to 2 s
# after DELAY, with the uncaught SysErr "in RuneStreamIOFn.flushOut". With
# HsMutants.protect catching every exception it prints "FAIL hs-mutants:
# SysErr: No such file or directory (noent)". With built-HU07 building in
# a directory of its own, both pass.
d=${1:-30}
RUN=$(mktemp -d)
RUNE_TEST_ROOT=$(pwd)
RUNE_TEST_RUN=$RUN
export RUNE_TEST_ROOT RUNE_TEST_RUN
bin/rune-test hs-mutants-good > "$RUN/good.out" 2>&1 || { cat "$RUN/good.out"; rm -rf "$RUN"; exit 1; }
start=$(date +%s)
( bin/rune-test hs-mutant HU07 > "$RUN/mutant.out" 2>&1
  echo "mutant: exit $?, $(( $(date +%s) - start )) s in" >> "$RUN/mutant.out" ) &
sleep "$d"
bin/rune-test hs-mutant-built HU07 > "$RUN/built.out" 2>&1
echo "built: exit $?, $(( $(date +%s) - start )) s in" >> "$RUN/built.out"
wait
cat "$RUN/mutant.out" "$RUN/built.out"
rm -rf "$RUN"
