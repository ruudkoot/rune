#!/bin/sh
# HOL4's kernel at work, timed inside HOL (docs/performance.md, *Measuring*;
# docs/plans/performance.md, E7):
#   scripts/hol-kernel.sh HOL [FILE]
# HOL is a HOL4 tree that has been built (bin/build), by Poly/ML or by Rune.
# FILE (scripts/hol-kernel.sml unless given) is run in a restored hol.state,
# after Arbint, Arbrat and HOL's preludes, as HOL's buildheap runs a script;
# it prints a line `HOLBENCH NAME: SECONDS` per workload, the processor time
# measured inside HOL. Poly/ML's runtime runs with one collector thread, so
# that its processor time is comparable. A HOL built by Rune (it has
# tools-rune) runs on the runevm it was built with, or on $RUNEVM (with
# $RUNEVM_OPTS, e.g. --jit-perf-map --stats), and with a cache of units of the
# script's own: $RUNE_CACHE, by default a copy of HOL's tools-rune/cache made
# once in tests/out/hol. Nothing is ever written into HOL. A run in which no
# workload printed its line fails.
set -u
[ $# -ge 1 ] && [ $# -le 2 ] || { echo "usage: scripts/hol-kernel.sh HOL [FILE]" >&2; exit 2; }
root=$(cd "$(dirname "$0")/.." && pwd)
hol=$(cd "$1" && pwd) || exit 2
file=${2:-$root/scripts/hol-kernel.sml}
case "$file" in /*) ;; *) file=$(pwd)/$file ;; esac
[ -x "$hol/bin/buildheap" ] && [ -f "$hol/bin/hol.state" ] || { echo "hol-kernel: $hol is not a built HOL4 (bin/buildheap, bin/hol.state)" >&2; exit 2; }
# a VM given by a path relative to here is the one meant
case "${RUNEVM:-}" in ''|/*) ;; *) RUNEVM=$(pwd)/$RUNEVM; export RUNEVM ;; esac
if [ -n "${RUNEVM:-}" ] && [ ! -x "$RUNEVM" ]; then echo "hol-kernel: $RUNEVM is not an executable VM" >&2; exit 2; fi
if [ -d "$hol/tools-rune" ]; then
  if [ -z "${RUNE_CACHE:-}" ]; then
    RUNE_CACHE=$root/tests/out/hol/cache-$(basename "$hol")
    if [ ! -d "$RUNE_CACHE" ]; then
      mkdir -p "$root/tests/out/hol"
      cp -R "$hol/tools-rune/cache" "$RUNE_CACHE.tmp" && mv "$RUNE_CACHE.tmp" "$RUNE_CACHE" || exit 2
    fi
  fi
  export RUNE_CACHE
fi
mkdir -p "$root/tests/out/hol"
log=$root/tests/out/hol/kernel.$$.log
state=$hol/bin/hol.state
set -- Arbint Arbrat "$hol/tools-poly/prelude.ML" "$hol/tools-poly/prelude2.ML" "$file"
if [ -d "$hol/tools-rune" ] && [ -n "${RUNEVM:-}${RUNEVM_OPTS:-}" ]; then
  # HOL's buildheap execs the VM HOL was built with, and takes no options of
  # the VM's: run what it runs, on $RUNEVM (else that VM), with $RUNEVM_OPTS
  vm=${RUNEVM:-$(sed -n 's/^exec \([^ ]*runevm\) .*/\1/p' "$hol/bin/buildheap")}
  [ -x "$vm" ] || { echo "hol-kernel: no runevm to run $hol on" >&2; exit 2; }
  # shellcheck disable=SC2086
  "$vm" ${RUNEVM_OPTS:-} --name "$hol/bin/buildheap" --restore "$state" -- --holstate="$state" "$@" 2>&1 | tee "$log"
else
  "$hol/bin/buildheap" --gcthreads=1 --holstate="$state" "$@" 2>&1 | tee "$log"
fi
n=$(grep -c '^HOLBENCH ' "$log")
rm -f "$log"
[ "$n" -gt 0 ] || { echo "hol-kernel: no workload ran" >&2; exit 1; }
