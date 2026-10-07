#!/bin/sh
# tools/heapsim/sweep2.sh [-P N] [--plan full|reduced] [--only Q] [--out DIR] TRACE...
# gcsim's sweeps over census traces of format 2 (docs/census.md), which made
# the simulator's tables of docs/plans/garbage-collector-v2.md (*The
# simulator*): for each trace directory, the configurations of each question
# run into DIR/sweep/QUESTION/NAME.tsv (DIR: tests/out/gcsim; bin/gcsim
# --header names the columns; one row per run), which report2.py turns into
# tables. Questions:
#   nursery  nursery 128K..32M x promotion 1|2, copying old space, bands lo, hi, near
#   old      old spaces x memory limit (none, 1.25..4 x max live), 1M nursery
#            (copy, mc Lisp-2, mc Jonkers, mlton, immix, segfit, best/next/first fit, chez)
#   old-n    the main old spaces at nurseries 256K and 4M, no limit and 2x
#   frag     Immix lines 64/128/256 x blocks 16K/32K/64K x defrag; LOS thresholds
#   mut      a mutable space scanned at every minor vs the barrier
#   satb     SATB: k 0.5..8 x start 0.5|0.75 on immix (no defrag), segfit, bestfit
#   order    promotion order: allocation, Cheney-like BFS and DFS over graph.bin, three shuffles (immix, segfit, bestfit, chez)
#   bits32   W4 sizes and 4-byte metadata pointers
#   events   per-collection events for the timeline (copier, nursery+copy,
#            immix, segfit, satb), in DIR/events/NAME.CONFIG.ev (timeline.py,
#            pauses.py)
# --plan reduced: nursery, old (no-limit and 2x only) and events, for large
# traces. N runs at a time (default 2), each under ulimit -v 6 GB and gcsim
# --max-mb 5000: a run takes about 26 bytes an object of the trace, 900 MB
# on the bootstrap's 34 million.
set -u
P=2; plan=full; only=""; out=tests/out/gcsim
while [ $# -gt 0 ]; do
  case "$1" in
    -P) P=$2; shift 2 ;;
    --plan) plan=$2; shift 2 ;;
    --only) only=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    -*) echo "usage: tools/heapsim/sweep2.sh [-P N] [--plan full|reduced] [--only Q] [--out DIR] TRACE..." >&2; exit 2 ;;
    *) break ;;
  esac
done
sim=$(cd "$(dirname "$0")/../.." && pwd)/bin/gcsim
mkdir -p "$out"; out=$(cd "$out" && pwd)
res=$out/sweep; evd=$out/events
mkdir -p "$res" "$evd"

configs() {   # question -> one gcsim argument line per run
  case "$1" in
  nursery)
    for b in lo hi near; do for n in 128K 256K 512K 1M 2M 4M 8M 16M 32M; do for p in 1 2; do
      echo "--old copy --nursery $n --promote $p --band $b"; done; done; done ;;
  old)
    lims="0 1.25 1.5 2 3 4"; [ $plan = reduced ] && lims="0 2"
    for l in $lims; do
      lim=""; [ "$l" != 0 ] && lim="--limit-x $l"
      for o in copy mc "mc --jonkers" mlton immix segfit bestfit nextfit firstfit chez; do echo "--nursery 1M --old $o $lim"; done
    done ;;
  old-n)
    for n in 256K 4M; do for l in 0 2; do lim=""; [ "$l" != 0 ] && lim="--limit-x $l"
      for o in copy immix segfit bestfit chez; do echo "--nursery $n --old $o $lim"; done; done; done ;;
  frag)
    for line in 64 128 256; do for blk in 16K 32K 64K; do for d in "" "--no-defrag"; do
      echo "--nursery 1M --old immix --line $line --block $blk $d"
      echo "--nursery 1M --old immix --line $line --block $blk $d --limit-x 1.5"
    done; done; done
    echo "--nursery 1M --old immix --exact-lines"
    for t in 2K 4K 8K; do echo "--nursery 1M --old immix --los $t"; done
    for t in 512 1025; do echo "--nursery 1M --old segfit --los $t"; done
    for t in 2K 8K 32K; do echo "--nursery 1M --old bestfit --los $t"; echo "--nursery 1M --old copy --los $t"; done ;;
  mut)
    for n in 256K 1M 4M; do echo "--nursery $n --old immix"; echo "--nursery $n --old immix --mutable-space"; done ;;
  satb)
    for o in "immix --no-defrag" segfit bestfit; do echo "--nursery 1M --old $o"; for k in 0.5 1 2 4 8; do for th in 0.5 0.75; do
      echo "--nursery 1M --old $o --satb $k --satb-start $th"; done; done; done ;;
  order)
    for o in immix segfit bestfit chez; do echo "--nursery 1M --old $o"; echo "--nursery 1M --old $o --order bfs"; echo "--nursery 1M --old $o --order dfs"
      for s in 1 2 3; do echo "--nursery 1M --old $o --shuffle $s"; done; done ;;
  bits32)
    for o in copy immix segfit bestfit; do
      echo "--nursery 1M --old $o"; echo "--nursery 1M --old $o --ptr 4"; echo "--nursery 1M --old $o --size W4 --ptr 4"; echo "--nursery 1M --old $o --size W4 --ptr 4 --limit-x 2"
    done ;;
  events)
    echo "--nursery 0 --old copy --heap-size 64M"
    echo "--nursery 0 --old copy --heap-size 4M"
    echo "--nursery 1M --old copy"; echo "--nursery 256K --old copy"; echo "--nursery 4M --old copy"
    echo "--nursery 1M --old immix"; echo "--nursery 1M --old segfit"; echo "--nursery 1M --old bestfit"; echo "--nursery 1M --old mc"
    echo "--nursery 1M --old segfit --satb 2"; echo "--nursery 1M --old immix --no-defrag --satb 2"; echo "--nursery 1M --old segfit --satb 2 --slice 64K" ;;
  esac
}
questions="nursery old old-n frag mut satb order bits32 events"
[ $plan = reduced ] && questions="nursery old events"
[ -n "$only" ] && questions=$only

status=0
for tr in "$@"; do
  name=$(basename "$tr")
  [ -f "$tr/meta.txt" ] || { echo "SKIP $name: not a format-2 trace"; status=1; continue; }
  for q in $questions; do
    mkdir -p "$res/$q"; out=$res/$q/$name.tsv
    start=$(date +%s)
    "$sim" --header > "$out"
    # the old-space questions do not use the stores; a stores.bin over 4 GB is read by the barrier questions only
    ns=""; case $q in old|old-n|frag|order|bits32) ns="--no-stores" ;; esac
    [ "$(stat -c %s "$tr/stores.bin" 2>/dev/null || echo 0)" -gt 4294967296 ] && [ "$q" != nursery ] && ns="--no-stores"
    export sim tr name evd q ns
    configs $q | sed "s/ *$//" | xargs -P "$P" -L 1 sh -c '
      ulimit -v 6291456
      ev=""
      if [ "$q" = events ]; then tag=$(echo "$*" | tr -d "-" | tr " " "_"); ev="--events $evd/$name.$tag.ev"; fi
      "$sim" --max-mb 5000 --trace "$tr" --workload "$name" "$@" $ev $ns' sh >> "$out" 2>> "$out.err"
    n=$(($(wc -l < "$out") - 1)); want=$(configs $q | wc -l)
    echo "sweep $name $q: $n/$want rows in $(( $(date +%s) - start )) s$( [ -s "$out.err" ] && echo " (stderr in $out.err)" )"
    [ "$n" = "$want" ] || status=1
  done
done
exit $status
