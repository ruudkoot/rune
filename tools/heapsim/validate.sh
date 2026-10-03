#!/bin/sh
# tools/heapsim/validate.sh [--out DIR] WORKLOAD...
# The simulator's copier model against the stock VM (docs/plans/heap-layout.md,
# *The experiments*): for each workload, whose census trace
# tests/out/census/WORKLOAD scripts/census.sh makes when it is missing, the
# stock VM (bin/runevm --jit=off --stats) runs the census's own command
# (the DONE file's cwd and cmd lines) at five settings -- an initial semispace
# of 4 MiB, 64 MiB and 256 MiB at --heap-fill 50, and 64 MiB at fills 25 and
# 80 -- and bin/heapsim replays the trace under L0 and the copier model in
# both bands. One row per setting:
#   workload heap fill | stock: collections semispace copied live gc-us | lo: ... | hi: ... | band width | verdict
# ok when the lower band's collections and semispace equal the stock's (the
# upper band, which counts everything born since the last sample as live,
# may trigger a collection or a growth the stock did not), the model's
# bytes are the stock's, and the stock's copied bytes and live data lie
# inside the band; a mismatch is a bug in the census or the model.
# Rows go to stdout and DIR/WORKLOAD.validate (DIR: tests/out/heapsim).
# Exits 1 on any verdict but ok. Part of make check-heapsim on two small
# workloads.
set -u
out=tests/out/heapsim
[ "${1:-}" = "--out" ] && { out=$2; shift 2; }
cd "$(dirname "$0")/../.."
root=$(pwd)
sim=$root/bin/heapsim
stock=$root/bin/runevm
settings="4194304:50 67108864:50 268435456:50 67108864:25 67108864:80"
mkdir -p "$out"
status=0
command -v timeout > /dev/null 2>&1 && limit="timeout 3600" || limit=""
for name in "$@"; do
  tr=tests/out/census/$name
  # a trace is kept from run to run, but not one of another program: where
  # the bytecode its DONE names is gone or newer than the trace (another
  # compiler made it since), the census is made again
  kept=""
  if grep -q '^cmd ' "$tr/DONE" 2> /dev/null; then
    rbc=$(sed -n 's/^cmd \([^ ]*\).*/\1/p' "$tr/DONE")
    [ -f "$rbc" ] && [ ! "$rbc" -nt "$tr/DONE" ] && kept=yes
  fi
  [ -n "$kept" ] || sh scripts/census.sh "$name" > "$out/$name.census.log" 2>&1 || { echo "FAIL $name: $(tail -1 "$out/$name.census.log")"; status=1; continue; }
  cwd=$(sed -n 's/^cwd //p' "$tr/DONE"); cmd=$(sed -n 's/^cmd //p' "$tr/DONE"); outf=$(sed -n 's/^out //p' "$tr/DONE")
  [ -n "$cmd" ] || { echo "FAIL $name: no cmd line in $tr/DONE (scripts/census.sh of M2 or later)"; status=1; continue; }
  $sim --check --trace "$tr" --layout L0 > "$out/$name.check" 2>&1 || { echo "CHECK $name: $(head -c 300 "$out/$name.check")"; status=1; }
  : > "$out/$name.validate"
  for s in $settings; do
    heap=${s%:*}; fill=${s#*:}
    # as scripts/census.sh ran the stock VM: the same directory and
    # arguments, standard input from /dev/null, the outputs to files,
    # the file the compiler writes not there yet (docs/testing.md)
    [ -n "$outf" ] && rm -f "$outf"
    # shellcheck disable=SC2086
    (cd "$cwd" && $limit "$stock" --jit=off --stats --heap-size "$heap" --heap-fill "$fill" $cmd < /dev/null > "$root/$out/$name.stdout" 2> "$root/$out/$name.stderr")
    line=$(grep '^runevm: [0-9]* collections' "$out/$name.stderr" | tail -1)
    [ -n "$line" ] || { echo "FAIL $name $heap $fill: no stats line: $(head -1 "$out/$name.stderr")"; status=1; continue; }
    # runevm: C collections, B bytes allocated, semispace S bytes, L live, copied X, max live M, gc U us
    set -- $(echo "$line" | sed 's/[,]//g')
    sc=$2; sb=$4; ss=$8; sl=${10}; sx=${13}; su=${18}
    lo=$($sim --trace "$tr" --workload "$name" --layout L0 --collector copier --heap-size "$heap" --heap-fill "$fill" --band lo | cut -f8,20,27,30,31)
    hi=$($sim --trace "$tr" --workload "$name" --layout L0 --collector copier --heap-size "$heap" --heap-fill "$fill" --band hi | cut -f8,20,27,30,31)
    set -- $lo; lb=$1; lx=$2; lc=$3; ls_=$4; ll=$5
    set -- $hi; hx=$2; hc=$3; hs=$4; hl=$5
    verdict=ok
    [ "$lc" = "$sc" ] || verdict=COLLECTIONS
    [ "$ls_" = "$ss" ] || verdict=$verdict/SEMISPACE
    [ "$lb" = "$sb" ] || verdict=$verdict/BYTES
    [ "$lx" -le "$sx" ] && [ "$hx" -ge "$sx" ] || verdict=$verdict/COPIED
    if [ "$verdict" = ok ]; then
      lmin=$ll; lmax=$hl; [ "$hl" -lt "$ll" ] && { lmin=$hl; lmax=$ll; }
      [ "$lmin" -le "$sl" ] && [ "$lmax" -ge "$sl" ] || verdict=LIVE
    fi
    [ "$verdict" = ok ] || status=1
    width=$(awk -v a=$lx -v b=$hx 'BEGIN{ if (a>0) printf "%.3f", 100*(b-a)/a; else print "0" }')
    row=$(printf '%s\t%s\t%s\t| %s %s %s %s %s us\t| %s %s %s %s\t| %s %s %s %s\t| %s%%\t%s' \
      "$name" "$heap" "$fill" "$sc" "$ss" "$sx" "$sl" "$su" "$lc" "$ls_" "$lx" "$ll" "$hc" "$hs" "$hx" "$hl" "$width" "$verdict")
    echo "$row"; echo "$row" >> "$out/$name.validate"
  done
done
[ $status = 0 ] && echo "heapsim validate: ok"
exit $status
