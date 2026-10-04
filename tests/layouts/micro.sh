#!/bin/sh
# tests/layouts/micro.sh -- the primitive operations alone: rdtsc cycles per operation
# from `harness micro` (least of 3 runs) per configuration and compiler,
# with an 8 MiB semispace (allocation stays in the L3 cache) and 64 MiB
# (allocation streams to memory). Writes $RES/harness-micro.tsv.
# Same idle rule as measure.sh (load below 1.5 before each run). Built by
# make -C tests/layouts CC=<cc>; CCS names the compilers (default cc).
cd "$(dirname "$0")" || exit 2
RES=../out/layouts
CCS=${CCS:-cc}
CONFIGS=${*:-"L0 L1 L1+REALIMM L1+PAIRS L2 L3 L3+NAN51 L4MONO L4UNI L4MONO+PAIRS L1+HDR4 L1+ALIGN16"}
OUT=$RES/harness-micro.tsv
printf 'cc\tconfig\tsemispace_mib\top\tcycles_per_op\n' > $OUT
load_over() { awk -v l="$(uptime | sed 's/.*load average: //; s/,.*//')" -v t=$1 'BEGIN { exit !(l > t) }'; }
for cfg in $CONFIGS; do for cc in $CCS; do for s in 8 64; do
  bin=../out/layouts/$cc/harness-$cfg; [ -x $bin ] || continue
  while load_over 1.5; do sleep 30; done
  for r in 1 2 3; do taskset -c 5 timeout 120 $bin micro -s $s 2>/dev/null | grep '^micro ' | awk -v cc=$cc -v cfg=$cfg -v s=$s '$1 == "micro" && $4 == "cycles/op" { print cc "\t" cfg "\t" s "\t" $2 "\t" $3 }'; done \
    | sort -t"$(printf '\t')" -k4,4 -k5,5g | awk -F'\t' '!seen[$4]++' >> $OUT
done; done; done
echo "micro.sh done: $OUT"
