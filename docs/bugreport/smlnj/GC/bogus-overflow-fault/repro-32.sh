#!/bin/sh
# repro-32.sh N [HEAP] [PREFIX...]: from the root of a tree with bin/rune-smlnj32 built, compile
# tests/basis/word.sml N times as the oracle cross of tests/runner/oracles.sml does (the runner's
# environment, its events.jsonl open on descriptor 3, -o and stderr in a run directory under
# tests/out/r), with sml started on HEAP (default bin/rune-smlnj32.heap) under PREFIX (for
# example setarch x86_64 -R); prints how many runs failed and the last run's message.
# BUGREPORT.md, On 32 bits.
n=$1; heap=${2:-bin/rune-smlnj32.heap}; [ $# -ge 2 ] && shift 2 || shift 1
sml=${SMLNJ32:-$HOME/.local/rune-hosts/smlnj32/bin/sml}
root=$(pwd)
run=$root/tests/out/r/$(date +%Y%m%d-%H%M%S)-$$
mkdir -p "$run/cross"
exec 3> "$run/events.jsonl"
fails=0
i=0
while [ $i -lt "$n" ]; do
  i=$((i + 1))
  rm -f "$run/cross/basis-word.smlnj32.rbc"
  if ! env RUNEVM_INTINF=sml RUNE_LINT=2 RUNE_TEST_CPUS=1 RUNE_TEST_ROOT="$root" RUNE_TEST_RUN="$run" "$@" \
       "$sml" @SMLload="${heap%.x86-linux}" --lib bin/../lib \
       tests/basis/harness.sml tests/basis/fn/numstr.sml tests/basis/fn/word_fn.sml tests/basis/word.sml \
       tests/basis/finish.sml -o "$run/cross/basis-word.smlnj32.rbc" \
       < /dev/null > /dev/null 2> "$run/cross/basis-word.smlnj32.err"; then
    fails=$((fails + 1)); last=$(head -n 1 "$run/cross/basis-word.smlnj32.err")
  fi
done
echo "$fails of $n failed${last:+: $last}"
