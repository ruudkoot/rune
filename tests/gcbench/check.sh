#!/bin/sh
# tests/gcbench/check.sh -- every subcommand of gcbench at tiny sizes with
# its self-checks on (check=1, README.md): the copies and marks reach every
# object, the barriers' remembered sets find every old-to-young pointer,
# the sweeps free the dead bytes, the stack scans agree, the replay
# allocators keep every object whole and apart (alloc-test, and H5 on a
# synthetic trace that mktrace writes), the latency chain is one cycle.
# Nothing is timed, so it may run on a loaded machine, and no counters are
# needed: one run is made with GCB_EV=none, the rest with what the machine
# allows. Built by `make gcbench`; run by `make check-gcbench`. Fails if a
# check fails or a run does not exit 0. The output of each run is in
# tests/out/gcbench/check/.
cd "$(dirname "$0")" || exit 2
BIN=../out/gcbench/gcbench
OUT=../out/gcbench/check
[ -x $BIN ] || { echo "no $BIN (make gcbench)"; exit 2; }
rm -rf $OUT && mkdir -p $OUT || exit 2
fail=0
# run NAME SUBCOMMAND [ARG=VALUE ...]: under timeout and ulimit -v, as every
# experimental binary (docs/testing.md)
run() {
  name=$1; shift
  if ( ulimit -v 4194304; exec timeout 120 $BIN "$@" check=1 ) > $OUT/$name.tsv 2> $OUT/$name.err; then
    echo "ok   $name: $(grep -vc '^#' $OUT/$name.tsv) rows"
  else
    echo "FAIL $name (exit $?): gcbench $* check=1"
    grep -m 5 'FAILED\|gcbench:\|harness:' $OUT/$name.err
    fail=1
  fi
}
T=$OUT/trace
run mktrace mktrace dir=$T objects=100K every=32K
run h1 h1 trace=$T nursery=64K,256K pf=0,256 reps=1
run h2 h2 live=32K,256K size=16,24,32,64,256 reps=1
run h3 h3 heap=256K size=16,24,32,64 live=0.1,0.5,0.9 reps=1
run h3-runs h3 heap=256K size=48 live=0.5 runs=1 reps=1
run alloc-test alloc-test objects=20K rounds=5 reserve=256M
run h5 h5 trace=$T nursery=0,64K factor=2 min=256K reserve=256M reps=1
run h5-immix h5 trace=$T nursery=64K alloc=immix line=64 exact=1 min=256K reserve=256M reps=1
# gcsim's operation stream, in miniature: places, frees, moves
awk 'BEGIN { print "# gcsim ops synthetic old=segfit size=W8"; s = 7
  for (i = 1; i <= 6000; i++) { s = (s * 1103515245 + 12345) % 2147483648
    printf "a %d %d 0 %d\n", i, 16 + 8 * (s % 40), (i % 500 == 0) ? 4 : 3
    if (i % 1000 == 0) for (j = i - 999; j <= i; j += 2) printf "f %d\n", j
    if (i % 1500 == 0) printf "m %d 24 0 3\n", i } }' > $OUT/ops.txt
run h5-ops h5 ops=$OUT/ops.txt reserve=256M majors=$OUT/ops-majors.tsv
run h6 h6 nursery=256K old=16M reps=1 n_inttable=20K n_impfor=50K n_lazyold=64K n_refcons=100K
run h7 h7 n=4K,16K reps=1
run h8 h8 frames=10,100 locals=4,16,70 rets=4,64 funcs=1,16 reps=1
run h9 h9 block=32K,256K touch=4M reps=1
run h10 h10 sizes=16K,256K,1M huge=both what=lat,latpg,bw reps=1
GCB_EV=none run h2-tsc h2 live=32K size=32 reps=1
grep -q '	tsc$' $OUT/h2-tsc.tsv || { echo "FAIL h2-tsc: the rows of GCB_EV=none do not say tsc"; fail=1; }
[ $fail = 0 ] && echo "check.sh: every check passed" || echo "check.sh: FAILED"
exit $fail
