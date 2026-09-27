#!/bin/sh
# tests/layouts/check.sh [CCNAME] -- every kernel under every built layout (make -C tests/layouts), at a small n
# with a small semispace (many collections: the rooting is tested) and at
# the same n with the default semispace; fails if any checksum differs
# between layouts or heap sizes. No lock needed (untimed).
cd "$(dirname "$0")" || exit 2
OUTDIR=../out/layouts
CCNAME=${1:-cc}
BINS=$(ls $OUTDIR/$CCNAME/harness-* 2>/dev/null) || { echo "no binaries in $OUTDIR/$CCNAME (make -C tests/layouts)"; exit 2; }
fail=0
# kernel n small_semispace_MiB
while read -r k n s; do
  ref=""; line=""
  for b in $BINS; do
    L=${b#$OUTDIR/$CCNAME/harness-}
    for semi in $s ""; do
      out=$(timeout 120 $b $k $n ${semi:+-s $semi} 2>/dev/null) || { echo "FAIL $L $k $n -s '$semi': exit $?"; fail=1; continue; }
      ck=$(echo "$out" | awk '{print $3}')
      if [ -z "$ref" ]; then ref=$ck; fi
      if [ "$ck" != "$ref" ]; then echo "MISMATCH $k: $L (-s '$semi') $ck != $ref"; fail=1; fi
    done
    line="$line $L"
  done
  echo "$k n=$n checksum $ref same for:$line"
done <<KERNELS
list_ops 300000 32
intmap 60000 8
strmap 60000 8
inttable 100000 24
closures 300000 8
int_loop 1 8
word_loop 2000000 4
real_regs 100000 4
real_array 1000000 32
strings 200000 4
poly_eq_tree 200000 24
gc_churn8 20000 32
gc_churn64 5000 128
KERNELS
[ $fail = 0 ] && echo "check.sh: all checksums agree" || echo "check.sh: FAILED"
exit $fail
