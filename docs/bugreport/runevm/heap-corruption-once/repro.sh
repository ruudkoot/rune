#!/bin/sh
# repro.sh TREE N JOBS [MODE]: the compile that aborted once (BUGREPORT.md), N times, JOBS at once,
# in the built tree TREE (a checkout of d551f19dd or later, after `make`). MODE: plain (bin/runevm, its
# default JIT; the default), nojit (--jit=off), mcheck (glibc's malloc checks and perturbation), asan
# (bin/runevm-asan, from `make bin/runevm-asan`). One line per run: index, exit status, and stderr's
# first line when the status is not 0.
TREE=$1; N=$2; JOBS=$3; MODE=${4:-plain}
OUT=${TMPDIR:-/tmp}/runevm-heap-repro.$$
mkdir -p "$OUT"
cd "$TREE" || exit 1
VM=bin/runevm; EXTRA=
case $MODE in
  nojit) EXTRA=--jit=off ;;
  mcheck) export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libc_malloc_debug.so.0 GLIBC_TUNABLES=glibc.malloc.check=3:glibc.malloc.perturb=165 ;;
  asan) VM=bin/runevm-asan; export ASAN_OPTIONS=detect_leaks=0:halt_on_error=1 ;;
esac
one() {
  "$VM" $EXTRA --heap-size 67108864 bin/rune.rbc --lib lib --target=stack -O0 \
    tests/lang/mod.functor.functions_trace.sml -o "$OUT/p$1.rbc" > /dev/null 2> "$OUT/e$1"
  c=$?; if [ $c -ne 0 ]; then echo "$1 $c $(head -1 "$OUT/e$1")"; else echo "$1 0"; fi
}
i=1
while [ "$i" -le "$N" ]; do
  j=0
  while [ "$j" -lt "$JOBS" ] && [ "$i" -le "$N" ]; do one "$i" & i=$((i+1)); j=$((j+1)); done
  wait
done
