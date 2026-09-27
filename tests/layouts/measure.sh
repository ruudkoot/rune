#!/bin/sh
# measure.sh -- perf stat of every (compiler, configuration, kernel) built
# in build/<cc>/, 5 runs each, the run with the fewest cycles kept; a
# kernel whose min-of-5 spread ((max-min)/min of cycles) exceeds 5% is run
# 5 more times. Appends to $RES/harness-raw.tsv (header written once).
#   measure.sh [-c "gcc-13 clang-18"] [-k "kernel ..."] [config ...]
# Timed measurements only on an idle machine: before every kernel's five
# runs the script waits for other make runs and for a 1-minute load below
# 1.5, and if the load is above 3 after the runs (something started
# meanwhile) it waits and reruns them. PERF names the perf binary.
cd "$(dirname "$0")" || exit 2
RES=../out/layouts
PERF=${PERF:-perf}
EVENTS=cycles:u,instructions:u,task-clock,page-faults,cache-misses,L1-dcache-load-misses,dTLB-load-misses,branch-misses,r0203:u
CCS=${CCS:-cc}
KERNELS=""
while [ $# -gt 0 ]; do
  case $1 in
    -c) CCS=$2; shift 2 ;;
    -k) KERNELS=$2; shift 2 ;;
    *) break ;;
  esac
done
CONFIGS=${*:-"L0 L1 L2 L3 L4MONO L4UNI L1+PAIRS L4MONO+PAIRS L4UNI+PAIRS L1+HDR4 L1+ALIGN16 L3+NAN51 L1+REALIMM L2+REALIMM L1+UNBOXED L1+FLATREAL L4UNI+FLATREAL L1+COMPACT L4MONO+COMPACT L1+BARRIER"}
ALL_KERNELS="list_ops intmap strmap inttable closures int_loop word_loop real_regs real_array strings poly_eq_tree gc_churn8 gc_churn64"
# the kernels a variant affects (the rest are the base layout's)
kernels_of() {
  case $1 in
    L1+REALIMM|L2+REALIMM) echo "real_regs real_array intmap" ;;
    L1+UNBOXED) echo "real_regs word_loop" ;;
    L1+FLATREAL|L4UNI+FLATREAL) echo "real_array" ;;
    L1+COMPACT|L4MONO+COMPACT) echo "strings" ;;
    L1+BARRIER) echo "inttable real_array" ;;
    *) echo "$ALL_KERNELS" ;;
  esac
}
RAW=$RES/harness-raw.tsv
mkdir -p $RES
[ -f $RAW ] || printf 'cc\tconfig\tkernel\tn\tchecksum\tcycles\tinstructions\ttask_clock_ms\tpage_faults\tcache_misses\tl1d_misses\tdtlb_misses\tbranch_misses\tstore_fwd_blocks\trdtsc_total\tgc_cycles\tgc_share\tspread\truns\n' > $RAW

load1() { uptime | sed 's/.*load average: //; s/,.*//'; }
load_over() { awk -v l="$(load1)" -v t=$1 'BEGIN { exit !(l > t) }'; }
wait_idle() {
  while pgrep -af 'make (check|test|matrix|windows|portability)' | grep -v 'grep\|measure.sh' >/dev/null; do sleep 60; done
  while load_over 1.5; do sleep 30; done
}

# one measured run: prints "cycles instr clock faults cachem l1d dtlb branch sfb | stdout-line"
one_run() {
  bin=$1; k=$2
  out=$($PERF stat -x, -e $EVENTS -o $RES/perf.$$ -- taskset -c 5 timeout 120 $bin $k 2>/dev/null) || return 1
  awk -F, -v line="$out" '
    /cycles:u/ { c=$1 } /instructions:u/ { i=$1 } /task-clock/ { t=$1 } /page-faults/ { pf=$1 }
    /^[0-9]+,,cache-misses/ { cm=$1 } /L1-dcache-load-misses/ { l1=$1 } /dTLB-load-misses/ { tlb=$1 }
    /branch-misses/ { bm=$1 } /r0203:u/ { sf=$1 }
    END { printf "%s %s %.1f %s %s %s %s %s %s | %s\n", c, i, t / 1000000, pf, cm, l1, tlb, bm, sf, line }' $RES/perf.$$
}

measure() {   # cc config kernel
  cc=$1; cfg=$2; k=$3; bin=../out/layouts/$cc/harness-$cfg
  [ -x $bin ] || { echo "no $bin"; return; }
  while :; do
    wait_idle
    best=""; minc=""; maxc=""; runs=0
    for pass in 1 2; do
      for r in 1 2 3 4 5; do
        res=$(one_run $bin $k) || { echo "FAIL $cc $cfg $k"; return; }
        c=${res%% *}; runs=$((runs+1))
        if [ -z "$minc" ] || [ "$c" -lt "$minc" ]; then minc=$c; best=$res; fi
        if [ -z "$maxc" ] || [ "$c" -gt "$maxc" ]; then maxc=$c; fi
      done
      spread=$(awk -v a=$minc -v b=$maxc 'BEGIN { printf "%.3f", (b-a)/a }')
      if [ "$(awk -v s=$spread 'BEGIN { print (s > 0.05) ? 1 : 0 }')" = 0 ]; then break; fi
    done
    if load_over 3.0; then echo "load $(load1) after $cc $cfg $k: waiting, rerunning"; continue; fi
    break
  done
  counters=${best%% | *}; line=${best#* | }
  set -- $line   # kernel n checksum rdtsc gc_cycles share
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$cc" "$cfg" "$1" "$2" "$3" "$(echo $counters | tr ' ' '\t')" "$4" "$5" "$6" "$spread" "$runs" >> $RAW
  echo "$cc $cfg $k: cycles $minc spread $spread runs $runs"
}

for cfg in $CONFIGS; do
  ks=${KERNELS:-$(kernels_of $cfg)}
  for cc in $CCS; do
    for k in $ks; do measure $cc $cfg $k; done
  done
done
rm -f $RES/perf.$$
echo "measure.sh done: $RAW"
