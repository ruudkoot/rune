#!/bin/sh
# tools/heapsim/sweep.sh [-P N] [--reduced] WORKLOAD...
# The simulator's matrix over a census trace (tests/out/census/WORKLOAD;
# scripts/census.sh): layouts L0, L1, L1+REALIMM, L2, L3, L3+NAN51, L4 (mono),
# L4+L4UNIFORM, L1+PAIRS, L4+PAIRS, and HDR4, ALIGN16 and COMPACT on each
# 8-byte layout; the copier at 4M to 1G; a nursery at 8 sizes and 2 promotion
# policies; sticky bits at 8; a large-object space at 3 thresholds; mutable
# objects segregated at 8; both bands; and --real-level call and result for
# the boxing layouts at the 64M copier. --reduced is the short matrix used on
# the large MLton traces (7 layouts, two copiers, two nurseries, band lo).
# N runs at a time (default 8). Output: tests/out/heapsim/sweep-WORKLOAD.tsv,
# one row per run (bin/heapsim --header names the columns), which
# tools/heapsim/report.py turns into the tables of docs/plans/heap-layout.md.
set -u
cd "$(dirname "$0")/../.."
P=8; reduced=0
while [ $# -gt 0 ]; do
  case "$1" in
    -P) P=$2; shift 2 ;;
    --reduced) reduced=1; shift ;;
    -*) echo "usage: tools/heapsim/sweep.sh [-P N] [--reduced] WORKLOAD..." >&2; exit 2 ;;
    *) break ;;
  esac
done
sim=$(pwd)/bin/heapsim
res=tests/out/heapsim
mkdir -p "$res"
ulimit -v 4194304 2> /dev/null

configs() {   # one line per run: LAYOUT VARIANT COLLECTOR-ARGS
  if [ $reduced = 1 ]; then
    for lv in L0:- L1:- L1:PAIRS L1:REALIMM L2:- L4:- L4:L4UNIFORM; do
      l=${lv%:*}; v=${lv#*:}
      echo "$l $v --collector copier --heap-size 64M --band lo $extra"
      echo "$l $v --collector copier --heap-size 4M --band lo $extra"
      echo "$l $v --collector nursery --nursery 1M --promote 1 --heap-size 4M --band lo $extra"
      echo "$l $v --collector nursery --nursery 4M --promote 1 --heap-size 4M --band lo $extra"
    done
    return
  fi
  layouts="L0:- L1:- L1:REALIMM L2:- L3:- L3:NAN51 L4:- L4:L4UNIFORM L1:PAIRS L4:PAIRS"
  for l in L1 L2 L3 L4; do for v in HDR4 ALIGN16 COMPACT; do layouts="$layouts $l:$v"; done; done
  for lv in $layouts; do
    l=${lv%:*}; v=${lv#*:}
    for b in lo hi; do
      for h in 4M 16M 64M 256M 1G; do echo "$l $v --collector copier --heap-size $h --band $b"; done
      for n in 256K 512K 1M 2M 4M 8M 16M 32M; do
        for p in 1 2; do echo "$l $v --collector nursery --nursery $n --promote $p --heap-size 4M --band $b"; done
        echo "$l $v --collector sticky --nursery $n --heap-size 4M --band $b"
        echo "$l $v --collector mutseg --nursery $n --promote 1 --heap-size 4M --band $b"
      done
      for t in 2K 8K 32K; do echo "$l $v --collector los --los $t --heap-size 64M --band $b"; done
    done
  done
  for lv in L1:- L1:REALIMM L2:- L3:- L4:- L4:L4UNIFORM; do
    l=${lv%:*}; v=${lv#*:}
    for b in lo hi; do for r in call result; do echo "$l $v --collector copier --heap-size 64M --band $b --real-level $r"; done; done
  done
}

status=0
for name in "$@"; do
  tr=tests/out/census/$name
  [ -f "$tr/DONE" ] || { echo "SKIP $name: no trace in $tr (scripts/census.sh $name)"; status=1; continue; }
  out=$res/sweep-$name.tsv
  # a stores.bin over 1 GB (a loop writing one array) is not read: boxes and pointer stores come from census.txt
  extra=""; if [ "$(stat -c %s "$tr/stores.bin" 2>/dev/null || echo 0)" -gt 1073741824 ]; then extra="--no-stores"; fi
  export extra sim tr name
  start=$(date +%s)
  "$sim" --header > "$out"
  configs | sed "s/ *$//" | xargs -P "$P" -L 1 sh -c 'l=$1; v=$2; shift 2; if [ "$v" = - ]; then "$sim" --trace "$tr" --workload "$name" --layout "$l" "$@"; else "$sim" --trace "$tr" --workload "$name" --layout "$l" --variant "$v" "$@"; fi' sh >> "$out" 2>> "$out.err"
  n=$(($(wc -l < "$out") - 1)); want=$(configs | wc -l)
  echo "sweep $name: $n/$want rows in $(( $(date +%s) - start )) s$( [ -s "$out.err" ] && echo " (errors in $out.err)" )"
  [ "$n" = "$want" ] || status=1
done
exit $status
