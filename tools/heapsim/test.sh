#!/bin/sh
# tools/heapsim/test.sh -- the simulator's unit tests (make check-heapsim):
# bin/heapsim's copier, on the trace's own sizes (W8), against
# bin/heapsim-gen's exact copier on synthetic traces of format 2. For each seed and sample interval, --check must pass
# (death.bin and the sizes reproduce samples.bin), and with fine samples both
# bands must give the truth's collections and semispace and bracket its
# copied bytes and live data; then every collector and layout runs without
# error on one trace.
set -u
cd "$(dirname "$0")/../.."
sim=bin/heapsim
gen=bin/heapsim-gen
out=tests/out/heapsim/test
rm -rf "$out"
mkdir -p "$out"
status=0
for seed in 1 2 3; do
  for smp in 65536 4096 512; do
    t=$out/s$seed-$smp
    truth=$($gen --out "$t" --objects 150000 --sample $smp --seed $seed --heap-size 4194304) || { echo "FAIL gen"; status=1; continue; }
    set -- $truth   # truth objects N bytes B samples K collections C semispace S copied X live Y
    tc=$9; ts=${11}; tx=${13}; ty=${15}
    $sim --check --trace "$t" > "$t/check" || { echo "FAIL check seed $seed sample $smp: $(cat "$t/check")"; status=1; }
    lo=$($sim --trace "$t" --layout W8 --collector copier --band lo | cut -f20,27,30,31)
    hi=$($sim --trace "$t" --layout W8 --collector copier --band hi | cut -f20,27,30,31)
    set -- $lo; lx=$1; lc=$2; ls_=$3; ly=$4
    set -- $hi; hx=$1; hc=$2; hs=$3; hy=$4
    ok=1
    # the bands bound liveness pointwise; the two runs' triggers drift apart by
    # up to the band's width, so the totals are checked with that slack (and
    # the drift can leave the lower band's total above the upper's)
    mn=$lx; mx=$hx; [ "$hx" -lt "$lx" ] && { mn=$hx; mx=$lx; }
    slack=$(( (mx - mn) / 2 + 1 ))
    [ $((mn - slack)) -le "$tx" ] && [ $((mx + slack)) -ge "$tx" ] || ok=0
    if [ $smp -le 4096 ]; then
      [ "$lc" = "$tc" ] && [ "$hc" = "$tc" ] && [ "$ls_" = "$ts" ] && [ "$hs" = "$ts" ] || ok=0
      [ $((ly - slack)) -le "$ty" ] && [ $((hy + slack)) -ge "$ty" ] || ok=0
    fi
    width=$(awk -v a=$mn -v b=$mx 'BEGIN{printf "%.2f", 100*(b-a)/a}')
    if [ $ok = 1 ]; then echo "ok   seed $seed sample $smp: collections $tc semispace $ts copied $mn <= $tx <= $mx (band $width%) live $ly <= $ty <= $hy"
    else echo "FAIL seed $seed sample $smp: truth $tc/$ts/$tx/$ty lo $lc/$ls_/$lx/$ly hi $hc/$hs/$hx/$hy"; status=1; fi
  done
done
t=$out/s1-4096
for c in copier "nursery --nursery 256K" "nursery --nursery 1M --promote 2" "sticky --nursery 512K" "los --los 2K" "mutseg --nursery 256K"; do
  for l in W8 L0 "L1" "L1 --variant REALIMM" L2 L3 "L3 --variant NAN51" L4 "L4 --variant L4UNIFORM" "L1 --variant PAIRS,HDR4,COMPACT" "L4 --variant ALIGN16"; do
    for b in lo hi; do
      $sim --trace "$t" --layout $l --collector $c --band $b > /dev/null || { echo "FAIL run: --layout $l --collector $c --band $b"; status=1; }
    done
  done
done
[ $status = 0 ] && echo "heapsim test: all passed"
exit $status
