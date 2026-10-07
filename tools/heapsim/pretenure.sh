#!/bin/sh
# tools/heapsim/pretenure.sh [--out DIR] LEARN-TRACE APPLY-TRACE [NURSERY] [OLD]
# Pretenuring by allocation site: the survival of each site's objects
# through their first minor is learned on LEARN-TRACE (the whole run, or its
# first half when LEARN-TRACE and APPLY-TRACE are the same: then the sites
# are applied to the second half only), then the sites with survival of at
# least X% (and 64K allocated) allocate straight into the old space of
# APPLY-TRACE, for X = 50, 80, 95. Sites are pcs of the bytecode: only runs
# of the same program (the compiler: bootstrap, compile-sigs, compile-hello)
# share them. One row per run into DIR/pretenure/LEARN-APPLY.NURSERY.OLD.tsv
# (DIR: tests/out/gcsim; gcsim's columns; pt_saved = bytes a minor would
# have copied, pt_garbage = pretenured bytes dead before the next minor, now
# old-space garbage), the sites learned in DIR/pretenure/LEARN.NURSERY.sites.
set -u
out=tests/out/gcsim
[ "${1:-}" = "--out" ] && { out=$2; shift 2; }
[ $# -ge 2 ] || { echo "usage: tools/heapsim/pretenure.sh [--out DIR] LEARN-TRACE APPLY-TRACE [NURSERY] [OLD]" >&2; exit 2; }
learn=$1; apply=$2; n=${3:-1M}; old=${4:-immix}
sim=$(cd "$(dirname "$0")/../.." && pwd)/bin/gcsim; out=$out/pretenure; mkdir -p "$out"
ln=$(basename "$learn"); an=$(basename "$apply")
tsv=$out/$ln-$an.$n.$old.tsv; sites=$out/$ln.$n.sites
ulimit -v 6291456
if [ "$learn" = "$apply" ]; then
  "$sim" --max-mb 5000 --trace "$learn" --nursery "$n" --old "$old" --learn "$sites" --learn-until 0.5 > /dev/null
  from="--pretenure-from 0.5"
else
  "$sim" --max-mb 5000 --trace "$learn" --nursery "$n" --old "$old" --learn "$sites" > /dev/null
  from=""
fi
"$sim" --max-mb 5000 --header --trace "$apply" --nursery "$n" --old "$old" > "$tsv"
for x in 50 80 95; do
  # shellcheck disable=SC2086
  "$sim" --max-mb 5000 --trace "$apply" --nursery "$n" --old "$old" --pretenure "$sites" --pretenure-x $x $from >> "$tsv" 2>> "$tsv.err"
done
echo "pretenure $ln -> $an ($n, $old): $(($(wc -l < "$tsv") - 1)) rows in $tsv"
