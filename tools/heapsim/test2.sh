#!/bin/sh
# tools/heapsim/test2.sh -- gcsim's closed-form tests (make check-gcsim; the
# first validation of docs/plans/garbage-collector-v2.md, *The simulator*):
# bin/heapsim-gen --pattern writes traces whose every death and sample is
# placed, and each model's answer is known beforehand. Then the identities:
# gcsim against sim.c's copier, nursery and sticky models on gen.c's random
# traces, in both bands. Runs under ulimit -v 2 GB; prints one line per
# check, exits 1 on a failure.
set -u
cd "$(dirname "$0")/../.."
ulimit -v 2097152 2> /dev/null
gen=bin/heapsim-gen; sim=bin/gcsim; old=bin/heapsim
out=tests/out/gcsim/test2
rm -rf "$out"; mkdir -p "$out"
status=0
# ev TRACE GCSIM-ARGS...: run gcsim with majors forced at samples 1 and 2, keep the events
ev() { t=$1; shift; "$sim" --max-mb 1024 --trace "$t" --nursery 0 --major-at-samples 1,2 --heap-size 16M --events "$out/ev" "$@" > "$out/row" || echo "gcsim failed: $*"; }
# field N COLUMN: COLUMN of the Nth major/compact event
field() { awk -F'\t' -v n="$1" -v c="$2" 'NR==2{for(i=1;i<=NF;i++)h[$i]=i} NR>2 && ($2=="major"||$2=="compact"){k++; if(k==n) print $h[c]}' "$out/ev"; }
# row COLUMN: a column of the summary row
row() { "$sim" --header --trace "$@" | awk -F'\t' -v c="$COL" 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next}{print $h[c]}'; }
check() {   # check NAME GOT WANT
  if [ "$2" = "$3" ]; then echo "ok   $1: $2"; else echo "FAIL $1: got $2, want $3"; status=1; fi
}

# --- alt: M objects of 32 bytes, the odd ones dead at sample 1, M/2 more that live ---
$gen --out "$out/alt32" --pattern alt --size 32 --count 8184 > /dev/null   # 8 pools of 1023 32-byte slots
M=8184; live=$((M / 2 * 32))
ev "$out/alt32" --old segfit
check "segfit alt32: marked" "$(field 1 marked_bytes)" $live
check "segfit alt32: free slots are half (usable)" "$(field 1 usable)" $live
check "segfit alt32: phase 2 refills the slots, no new pool" "$(field 2 old_committed)" $((8 * 32768))
check "segfit alt32: usable after the refill" "$(field 2 usable)" 0
for p in bestfit nextfit firstfit; do
  ev "$out/alt32" --old $p
  check "$p alt32: held = live" "$(field 1 held)" $live
  check "$p alt32: holes refilled, the heap unchanged" "$(field 2 old_committed)" "$(field 1 old_committed)"
done
ev "$out/alt32" --old immix --exact-lines --no-defrag
check "immix alt32 (2 of 4 per line live): every line held" "$(field 1 held)" $((M * 32))
ev "$out/alt32" --old chez
check "chez alt32: first major marks in place (nothing usable)" "$(field 1 usable)" 0
check "chez alt32: second major copies the 50%-live segments' live bytes" "$(field 2 evac_bytes)" $live
ev "$out/alt32" --old mc
check "mc alt32: compaction moves exactly the live bytes" "$(field 1 moved_bytes)" $live
check "mc alt32: nothing moves when nothing died" "$(field 2 moved_bytes)" 0
ev "$out/alt32" --old copy
check "copy alt32: copies exactly the live bytes" "$(field 1 moved_bytes)" $live

# --- alt128: line-sized objects (128 bytes), alternate deaths ---
$gen --out "$out/alt128" --pattern alt --size 128 --count 2048 > /dev/null    # 8 blocks of 256 lines
ev "$out/alt128" --old immix --exact-lines --no-defrag
check "immix alt128 exact lines: 50% of the lines held" "$(field 1 held)" 131072
check "immix alt128 exact lines: 50% usable" "$(field 1 usable)" 131072
check "immix alt128 exact lines: refilled, no new block" "$(field 2 old_committed)" 262144
ev "$out/alt128" --old immix --no-defrag
check "immix alt128 conservative: one usable line a block (line 0)" "$(field 1 usable)" $((8 * 128))
check "immix alt128 conservative: phase 2 needs ceil(1016/256) more blocks" "$(field 2 old_committed)" $((12 * 32768))
ev "$out/alt128" --old immix --line 64 --no-defrag
check "immix alt128 64-byte lines: one line of each 2-line hole, both at a block's start" "$(field 1 usable)" $((1024 * 64 + 8 * 64))
ev "$out/alt128" --old immix --exact-lines --line 256 --no-defrag
check "immix alt128 256-byte lines: no line free" "$(field 1 usable)" 0

# --- line1: one 16-byte survivor per 128-byte line ---
$gen --out "$out/line1" --pattern line1 --size 16 --count 16384 --keep 8 > /dev/null
for v in "--exact-lines" ""; do
  # shellcheck disable=SC2086
  ev "$out/line1" --old immix --no-defrag $v
  check "immix line1 $v: no reclaimable line" "$(field 1 usable)" 0
  check "immix line1 $v: marked 1/8" "$(field 1 marked_bytes)" 32768
done
ev "$out/line1" --old segfit
check "segfit line1: free slots 7/8 of 9 pools" "$(field 1 usable)" $((9 * 2046 * 16 - 32768))

# --- nurs: survival, promotion, the remembered set and cards at real addresses ---
$gen --out "$out/nurs" --pattern nurs --nursery-bytes 65536 --windows 10 --size 16 --stores 100 > /dev/null
for b in lo hi; do for o in copy immix segfit bestfit chez; do
  COL=promoted;     check "nurs p1 $o $b: promoted = array + 8 x 32K" "$(row "$out/nurs" --nursery 64K --promote 1 --band $b --old $o --big off)" 264192
  COL=promoted;     check "nurs p2 $o $b: promoted = the array" "$(row "$out/nurs" --nursery 64K --promote 2 --band $b --old $o --big off)" 2048
  COL=surv_copied;  check "nurs p2 $o $b: survivor space copies" "$(row "$out/nurs" --nursery 64K --promote 2 --band $b --old $o --big off)" 264192
  COL=remset_total; check "nurs p1 $o $b: 100 slots x 7 minors" "$(row "$out/nurs" --nursery 64K --promote 1 --band $b --old $o --big off)" 700
  COL=cards_total;  check "nurs p1 $o $b: 2 cards x 7 minors" "$(row "$out/nurs" --nursery 64K --promote 1 --band $b --old $o --big off)" 14
done; done
COL=minors; check "nurs: 9 minors" "$(row "$out/nurs" --nursery 64K --old copy --big off)" 9

# --- satb: a cycle at sample 1, the odd objects dying during it, black objects after ---
$gen --out "$out/satb" --pattern satb --size 32 --count 8184 > /dev/null
"$sim" --max-mb 1024 --trace "$out/satb" --nursery 0 --old segfit --satb 2 --slice 4096 --satb-at-sample 1 --major-at-samples 2 --heap-size 16M --band lo --events "$out/ev" > "$out/row"
COL=satb_float_total; check "satb: floating garbage = the odd objects" "$(row "$out/satb" --nursery 0 --old segfit --satb 2 --slice 4096 --satb-at-sample 1 --major-at-samples 2 --heap-size 16M --band lo)" 130944
check "satb: the cycle's sweep frees nothing (all alive at the snapshot)" "$(awk -F'\t' 'NR==2{for(i=1;i<=NF;i++)h[$i]=i} NR>2 && $2=="satb-end"{print $h["swept_bytes"]}' "$out/ev")" 0
check "satb: the cycle marks the snapshot's live bytes" "$(awk -F'\t' 'NR==2{for(i=1;i<=NF;i++)h[$i]=i} NR>2 && $2=="satb-end"{print $h["marked_bytes"]}' "$out/ev")" 261888
check "satb: it ends after work/k bytes (one 4K slice's grain)" "$(awk -F'\t' 'NR==2{for(i=1;i<=NF;i++)h[$i]=i} NR>2 && $2=="satb-end"{print ($h["clock"] >= 392832 && $h["clock"] < 392832 + 4096) ? "yes" : "no"}' "$out/ev")" yes
check "satb: the next major frees the floating garbage" "$(field 1 swept_bytes)" 130944

# --- identities on gen.c's random traces ---
$gen --out "$out/g1" --objects 300000 --sample 4096 --seed 1 --heap-size 4194304 > "$out/g1.truth"
for b in lo hi; do
  want=$($old --trace "$out/g1" --layout W8 --collector copier --band $b | cut -f20,27)
  got=$("$sim" --header --trace "$out/g1" --nursery 0 --old copy --band $b | awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next}{print $h["copied_major"]"\t"$h["majors"]}')
  check "identity: copy, no nursery == sim.c copier ($b)" "$got" "$want"
  for n in 256K 1M; do
    want=$($old --trace "$out/g1" --layout W8 --collector nursery --nursery $n --promote 1 --band $b | cut -f20-22,26,27)
    got=$("$sim" --header --trace "$out/g1" --nursery $n --old copy --minor-at-samples --full promote --big off --band $b |
          awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next}{print $h["copied_total"]"\t"$h["copied_minor"]"\t"$h["copied_major"]"\t"$h["minors"]"\t"$h["majors"]}')
    check "identity: nursery $n + copy == sim.c nursery ($b)" "$got" "$want"
    want=$($old --trace "$out/g1" --layout W8 --collector sticky --nursery $n --band $b | cut -f23,24,26,27)
    got=$("$sim" --header --trace "$out/g1" --old sticky-immix --nursery $n --line 8 --exact-lines --no-defrag --los off --minor-at-samples --trigger-sim --band $b |
          awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next}{printf "%s\t%s\t%s\t%s\n", $h["surv_first"], $h["marked_major"], $h["minors"], $h["majors"]}')
    check "identity: sticky-immix 8-byte lines == sim.c sticky, marked bytes ($n, $b)" "$got" "$want"
  done
done
[ $status = 0 ] && echo "gcsim test2: all passed"
exit $status
