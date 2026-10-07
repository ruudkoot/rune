#!/bin/sh
# measure.sh -- a timed run of gcbench (README.md, *How it measures*):
#   measure.sh NAME [-n RUNS] [-e "mem l2"] [-c CPU] [-m KiB] -- SUBCOMMAND [ARG=VALUE ...]
# RUNS processes (5) for each event set (mem), each pinned to one core
# (taskset -c CPU, 5 by default) under ulimit -v KiB (4 GiB) and timeout
# 3600. A run starts only when the 1-minute load is below LOADMAX (1.5)
# and MemAvailable is at least the ulimit plus SPARE KiB (8 GiB); it is run
# again when the load rose above twice LOADMAX (3 at least) meanwhile.
# The rows of every process go to ../out/gcbench/NAME.raw.tsv (the run's
# number appended), and NAME.tsv keeps for each (exp, case, evset) the row
# with the fewest cycles -- the least of the runs, each already the least
# of its repetitions -- with the spread of the runs' cycles (max/min - 1)
# as its last column. NAME.log has the command, the loads, stderr and
# /usr/bin/time's "%U %S %R %M" of every process. The binary is copied to
# NAME.bin first, so that a build meanwhile does not change the run.
# A machine shared with other timed work names its exclusive lock in
# GCB_LOCK, a command that runs its arguments while it holds the lock
# (the roadmap's drafts: GCB_LOCK="DRAFTS/lock.sh timed gcbench");
# measure.sh then runs itself under it, once.
if [ -n "$GCB_LOCK" ] && [ -z "$GCB_LOCKED" ]; then
  GCB_LOCKED=1; export GCB_LOCKED
  # (the lock's command may change directory: back to this one, by name)
  self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  exec $GCB_LOCK sh -c 'cd "$1" && shift && exec sh "$@"' sh "$PWD" "$self" "$@"
fi
cd "$(dirname "$0")" || exit 2
OUT=../out/gcbench
BIN=$OUT/gcbench
[ $# -gt 0 ] || { echo "usage: measure.sh NAME [-n RUNS] [-e \"mem l2\"] [-c CPU] [-m KiB] -- SUBCOMMAND [ARG=VALUE ...]"; exit 2; }
NAME=$1; shift
RUNS=5; EVS="mem"; CPU=5; VMEM=4194304; LOADMAX=${LOADMAX:-1.5}; SPARE=${SPARE:-8388608}
RERUN=$(awk -v m=$LOADMAX 'BEGIN { print (m * 2 > 3 ? m * 2 : 3) }')
while [ $# -gt 0 ]; do
  case $1 in
    -n) RUNS=$2; shift 2 ;;
    -e) EVS=$2; shift 2 ;;
    -c) CPU=$2; shift 2 ;;
    -m) VMEM=$2; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
[ -x $BIN ] || { echo "measure.sh: build first (make gcbench)"; exit 2; }
load1() { cut -d' ' -f1 /proc/loadavg; }
load_over() { awk -v l="$(load1)" -v t=$1 'BEGIN { exit !(l > t) }'; }
avail_kib() { awk '/^MemAvailable:/ { print $2 }' /proc/meminfo; }
mem_short() { [ "$(avail_kib)" -lt $((VMEM + SPARE)) ]; }
TIME=""; [ -x /usr/bin/time ] && TIME="/usr/bin/time -f time_%U_%S_%R_%M -o $OUT/$NAME.time"
cp $BIN $OUT/$NAME.bin; BIN=$OUT/$NAME.bin
RAW=$OUT/$NAME.raw.tsv; LOG=$OUT/$NAME.log
: > $RAW
echo "# $(date '+%F %T') measure.sh $NAME -n $RUNS -e \"$EVS\" -c $CPU -m $VMEM LOADMAX=$LOADMAX -- $*" > $LOG
echo "# built with: $(cat $OUT/flags.txt 2>/dev/null)" >> $LOG
[ "$LOADMAX" = 1.5 ] || echo "# UNDER LOAD: runs start at a 1-minute load below $LOADMAX, not 1.5: cycles are not an idle machine's" >> $LOG
for ev in $EVS; do
  r=1
  while [ $r -le $RUNS ]; do
    while load_over $LOADMAX || mem_short; do sleep 15; done
    echo "# run $r ($ev) starts at load $(load1)" >> $LOG
    rm -f $OUT/$NAME.time
    ( ulimit -v $VMEM; GCB_EV=$ev exec $TIME taskset -c $CPU timeout 3600 $BIN "$@" ) > $OUT/$NAME.out 2>> $LOG
    st=$?
    [ -f $OUT/$NAME.time ] && tr '_' ' ' < $OUT/$NAME.time >> $LOG
    if [ $st != 0 ]; then echo "measure.sh: $NAME failed ($st)"; cat $OUT/$NAME.out >> $LOG; exit 1; fi
    if load_over $RERUN; then echo "# load $(load1) after run $r ($ev): rerun" >> $LOG; continue; fi
    grep -v '^#' $OUT/$NAME.out | sed "s/\$/	$r/" >> $RAW
    echo "# run $r ($ev) done at load $(load1)" >> $LOG
    r=$((r+1))
  done
done
printf '%s\trun\tspread\n' "$(grep '^#exp' $OUT/$NAME.out | head -1)" > $OUT/$NAME.tsv
# the least cycles per (exp, case, evset): the row of that run, and the
# spread of the runs' cycles as its last column
awk -F'\t' 'BEGIN { OFS = "\t" }
  { k = $1 FS $2 FS $15; if (!(k in best) || $5 + 0 < min[k]) { min[k] = $5 + 0; best[k] = $0 }
    if (!(k in max) || $5 + 0 > max[k]) max[k] = $5 + 0; if (!(k in ord)) { ord[k] = n++; key[n - 1] = k } }
  END { for (i = 0; i < n; i++) { k = key[i]; sp = min[k] > 0 ? max[k] / min[k] - 1 : 0; printf "%s\t%.3f\n", best[k], sp } }' $RAW >> $OUT/$NAME.tsv
rm -f $OUT/$NAME.out $OUT/$NAME.time
echo "measure.sh: $OUT/$NAME.tsv"
