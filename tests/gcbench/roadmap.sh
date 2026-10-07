#!/bin/sh
# roadmap.sh -- the timed runs that made the gcbench tables of
# docs/plans/garbage-collector-v2.md (*The harness*; the drafts'
# results/gcbench-*.md name each command), each by measure.sh into
# ../out/gcbench/NAME.tsv, in the order they were made; report.py then
# writes the tables from them. Hours of an idle machine.
#   GCB_TRACES=DIR [GCB_OPS=FILE] roadmap.sh [h10 h2 h8 h1 h6 h3 h9 h7 h5 h5-ops]
# H1 and H5 replay the census traces under $GCB_TRACES (docs/census.md):
# bootstrap, sampled every 32 KiB, for both, and for H5 also compile-sigs,
# runedoc-page and six of MLton's benchmarks. h5-ops replays the
# simulator's old-space stream for the bootstrap, $GCB_OPS, made by
#   gcsim --trace TRACES/bootstrap --nursery 1M --old segfit --major-every 16M --ops FILE
# (tools/heapsim), with the majors into ../out/gcbench/ops/bootstrap.majors.tsv.
# Set GCB_LOCK for the machine's lock (measure.sh).
cd "$(dirname "$0")" || exit 2
M="sh ./measure.sh"
OUT=$(mkdir -p ../out/gcbench && cd ../out/gcbench && pwd)
F=$OUT/h5-frag.tsv
WHAT=${*:-"h10 h2 h8 h1 h6 h3 h9 h7 h5 h5-ops"}
need_traces() { [ -n "$GCB_TRACES" ] || { echo "roadmap.sh: $1 needs GCB_TRACES (a directory of census traces)"; exit 2; }; }
for w in $WHAT; do
  case $w in
  h10)
    $M h10-lat -n 5 -- h10 what=lat || exit 1
    $M h10-l3 -n 5 -- h10 what=lat,latpg huge=both sizes=2M,3M,3.5M,4M,4.5M,5M,5.5M,6M,7M,8M,12M,16M,24M || exit 1
    $M h10-l3b -n 3 -- h10 what=lat,latpg huge=0 sizes=4M,6M,8M,12M,16M,24M || exit 1
    $M h10-bw -n 5 -- h10 what=bw sizes=8K,16K,32K,64K,128K,256K,512K,1M,2M,4M,8M,16M,32M,64M,256M || exit 1 ;;
  h2)
    $M h2-small -n 5 -- h2 live=32K,1M || exit 1
    $M h2-big -n 3 -- h2 live=128M size=16,32,64,256 reps_big=3 || exit 1 ;;
  h8) $M h8 -n 3 -- h8 || exit 1 ;;
  h1)
    need_traces h1
    $M h1 -n 3 -e "mem l2" -m 6291456 -- h1 trace=bootstrap || exit 1
    $M h1-huge -n 3 -m 6291456 -- h1 trace=bootstrap huge=1 pf=0 nursery=256K,1M,4M,16M,32M || exit 1 ;;
  h6) $M h6 -n 3 -- h6 || exit 1 ;;
  h3) $M h3 -n 3 -- h3 || exit 1 ;;
  h9) $M h9 -n 5 -- h9 || exit 1 ;;
  h7) $M h7 -n 5 -m 6291456 -- h7 || exit 1 ;;
  h5)
    need_traces h5
    : > $F
    B="trace=bootstrap frag=$F"
    $M h5-boot -n 2 -m 6291456 -- h5 $B alloc=bump,immix,segfit,bestfit,nextfit nursery=256K,1M,4M factor=2 || exit 1
    $M h5-boot-ff -n 1 -m 6291456 -- h5 $B alloc=firstfit nursery=1M factor=2 || exit 1
    $M h5-boot-factor -n 1 -m 6291456 -- h5 $B nursery=1M factor=1.5,3 graph=0 || exit 1
    $M h5-boot-line64 -n 1 -m 6291456 -- h5 $B nursery=1M alloc=immix line=64 graph=0 || exit 1
    $M h5-boot-line256 -n 1 -m 6291456 -- h5 $B nursery=1M alloc=immix line=256 graph=0 || exit 1
    $M h5-boot-exact -n 1 -m 6291456 -- h5 $B nursery=1M alloc=immix exact=1 graph=0 || exit 1
    for t in compile-sigs runedoc-page mlton-mlyacc mlton-knuth-bendix mlton-barnes-hut mlton-lexgen mlton-nucleic mlton-ray; do
      $M h5-$t -n 1 -m 6291456 -- h5 trace=$t frag=$F nursery=256K,1M,4M factor=2 || exit 1
      # with a 1 MiB floor, so that the small old spaces collect
      $M h5-$t-min1M -n 1 -m 6291456 -- h5 trace=$t frag=$F nursery=256K,1M,4M factor=2 min=1M alloc=bump,immix,segfit,bestfit,nextfit || exit 1
    done ;;
  h5-ops)
    [ -n "$GCB_OPS" ] || { echo "roadmap.sh: h5-ops needs GCB_OPS (gcsim's --ops stream); skipped"; continue; }
    mkdir -p $OUT/ops; : > $OUT/ops/bootstrap.majors.tsv
    $M h5-ops -n 1 -m 6291456 -- h5 ops=$GCB_OPS alloc=segfit,bestfit,nextfit,immix majors=$OUT/ops/bootstrap.majors.tsv frag=$F || exit 1 ;;
  *) echo "roadmap.sh: no experiment $w"; exit 2 ;;
  esac
done
echo "roadmap.sh: done; python3 report.py writes the tables"
