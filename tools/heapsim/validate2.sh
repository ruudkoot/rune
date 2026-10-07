#!/bin/sh
# tools/heapsim/validate2.sh [--vm VM] [--out DIR] [--settings "H:F ..."] TRACE...
# gcsim's copying model with no nursery (runtime/heap.c's policy) against the
# stock VM, on census traces of format 2 (docs/census.md): validate.sh for
# gcsim, with the clock of every collection. For each trace directory, the
# stock VM (default bin/runevm, whose --gc-log is docs/runtime.md's) runs the
# trace's own command (its DONE file's cwd and cmd lines, --jit=off as the
# census ran; the file the compiler writes deleted before each run) at five
# settings: an initial semispace of 4, 64 and 256 MiB at --heap-fill 50, and
# 64 MiB at fills 25 and 80. gcsim replays the trace with the same settings
# in both bands. Logs and events go to DIR (default tests/out/gcsim/validate).
# One row per setting:
#   trace heap fill | stock: collections semispace copied | lo: ... | hi: ... | clocks | verdict
# ok when the lower band's collections and final semispace equal the
# stock's and the stock's copied bytes lie in the band; the clocks column
# gives the largest difference between a stock collection's clock (bytes
# allocated, boxes included) and the lower band's (zero where collections
# fall on samples; the band's drift otherwise). The VM runs under ulimit -v 4 GB and timeout 1200.
set -u
here=$(cd "$(dirname "$0")/../.." && pwd)
vm=$here/bin/runevm
out=tests/out/gcsim/validate
settings="4194304:50 67108864:50 268435456:50 67108864:25 67108864:80"
while [ $# -gt 0 ]; do
  case "$1" in
    --vm) vm=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --settings) settings=$2; shift 2 ;;
    *) break ;;
  esac
done
gcsim=$here/bin/gcsim
case "$vm" in /*) ;; *) vm=$(pwd)/$vm ;; esac   # it runs in the trace's directory
mkdir -p "$out"; out=$(cd "$out" && pwd)
status=0
for tr in "$@"; do
  name=$(basename "$tr"); newf=""
  cwd=$(sed -n 's/^cwd //p' "$tr/DONE"); cmd=$(sed -n 's/^cmd //p' "$tr/DONE"); outf=$(sed -n 's/^out //p' "$tr/DONE")
  [ -n "$cmd" ] || { echo "FAIL $name: no cmd in $tr/DONE"; status=1; continue; }
  # the compiler's output: the file DONE's out line names (the program
  # must run exactly as the census ran it, and any other path is another
  # run: the compiler's counts depend on it). Deleted before each run, as
  # scripts/census.sh does (the compiler reads it first); nothing else in
  # the trace's directory is touched.
  newf=$outf
  # standard input: DONE's stdin line, else the .input beside the bytecode (scripts/census.sh --stdin), else nothing
  stdin=$(sed -n 's/^stdin //p' "$tr/DONE"); rbc=${cmd%% *}
  [ -n "$stdin" ] || { [ -f "${rbc%.rbc}.input" ] && stdin=${rbc%.rbc}.input; }
  [ -n "$stdin" ] || stdin=/dev/null
  for s in $settings; do
    heap=${s%:*}; fill=${s#*:}
    log=$out/$name.$heap.$fill.gclog
    # the compiler looks at its output file before writing it (docs/testing.md): every run starts without it
    [ -n "${newf:-}" ] && rm -f "$newf"
    # shellcheck disable=SC2086
    (cd "$cwd" && ulimit -v 4194304 && timeout 1200 "$vm" --jit=off --stats --gc-log "$log" --heap-size "$heap" --heap-fill "$fill" $cmd < "$stdin" > "$out/$name.stdout" 2> "$out/$name.stderr")
    [ -s "$log" ] || { echo "FAIL $name $heap $fill: no gc log ($(head -c 200 "$out/$name.stderr"))"; status=1; continue; }
    # stock: collections, final semispace, copied, and the clock of each pass (bytes + box_bytes)
    st=$(awk -v h0="$heap" '!/^#/ {n++; c+=$10; h=$21} END {print n+0, (n ? h : h0), c+0}' "$log")
    pre=$(sed -n "s/^pretrace_bytes //p" "$tr/meta.txt"); awk -v pre="${pre:-0}" '!/^#/ {print $4+$8+pre}' "$log" > "$out/$name.$heap.$fill.stock-clocks"
    lo=$("$gcsim" --max-mb 5000 --trace "$tr" --nursery 0 --old copy --heap-size "$heap" --heap-fill "$fill" --band lo --events "$out/$name.$heap.$fill.lo.ev" --header |
         awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next}{print $h["majors"], $h["final_semispace"], $h["copied_major"]}')
    hi=$("$gcsim" --max-mb 5000 --trace "$tr" --nursery 0 --old copy --heap-size "$heap" --heap-fill "$fill" --band hi --header |
         awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next}{print $h["majors"], $h["final_semispace"], $h["copied_major"]}')
    awk -F'\t' '!/^#/ && $2=="major" {print $4}' "$out/$name.$heap.$fill.lo.ev" > "$out/$name.$heap.$fill.lo-clocks"
    set -- $st; sc=$1; ss=$2; sx=$3
    set -- $lo; lc=$1; lsz=$2; lx=$3
    set -- $hi; hc=$1; hsz=$2; hx=$3
    # ok: the lower band's collections and semispace are the stock's, and the stock's copied bytes lie in the
    # band (with half its width as slack: the two runs' collections drift apart by up to the band);
    # band: the stock lies between the bands (a decision -- grow, collect -- that the band's width flips);
    # FAIL otherwise
    # the clock of each collection, the stock's against the lower band's: equal at a sample, within the band's drift between samples
    clocks=$(paste "$out/$name.$heap.$fill.stock-clocks" "$out/$name.$heap.$fill.lo-clocks" | awk 'NF==2{d=$2-$1; if(d<0)d=-d; if(d>m)m=d} END{printf "maxdiff=%d", m+0}')
    slack=$(( (hx > lx ? hx - lx : lx - hx) / 2 + 1 ))
    inband() { lo_=$1; hi_=$2; v=$3; [ "$lo_" -gt "$hi_" ] && { t=$lo_; lo_=$hi_; hi_=$t; }; [ "$v" -ge "$lo_" ] && [ "$v" -le "$hi_" ]; }
    verdict_pre=no; [ "$lc" = "$sc" ] && [ "$lsz" = "$ss" ] && [ $((lx - slack)) -le "$sx" ] && [ $((hx + slack)) -ge "$sx" ] && verdict_pre=ok
    mn=$lx; mx=$hx; [ "$hx" -lt "$lx" ] && { mn=$hx; mx=$lx; }
    elif_ok=0; inband "$lc" "$hc" "$sc" && inband "$lsz" "$hsz" "$ss" && inband $((mn - slack)) $((mx + slack)) "$sx" && elif_ok=1
    if [ "$verdict_pre" = ok ]; then verdict=ok
    elif [ $elif_ok = 1 ]; then verdict=band
    else verdict=FAIL; fi
    [ "$verdict" = FAIL ] && status=1
    width=$(awk -v a="$lx" -v b="$hx" 'BEGIN{ if (a>0) printf "%.3f", 100*(b-a)/a; else print "0" }')
    printf '%s\t%s\t%s\t| %s %s %s\t| %s %s %s\t| %s %s %s\t| %s%%\t%s\t%s\n' "$name" "$heap" "$fill" "$sc" "$ss" "$sx" "$lc" "$lsz" "$lx" "$hc" "$hsz" "$hx" "$width" "$clocks" "$verdict"
  done
done
exit $status
