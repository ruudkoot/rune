#!/bin/sh
# tools/heapsim/validate-proto.sh --vm VM [--out DIR] [--nurseries "N ..."] TRACE...
# gcsim's nursery + copying old space (--full appel: the prototype's policy)
# against a VM with a nursery in front of today's copier that takes
# --nursery N and writes --gc-log (docs/runtime.md's columns, minor and full
# lines): the roadmap's prototype (docs/plans/garbage-collector-v2.md, *The
# prototype*), never committed, until the nursery of its M3 is. On census
# traces of format 2 (docs/census.md); the VM runs the trace's own command
# (DONE's cwd, cmd, out; stdin as validate2.sh), --jit=off, under ulimit -v
# 4 GB; its logs go to DIR (default tests/out/gcsim/vproto). One row per
# nursery size:
#   trace N | proto: minors fulls promoted cards_dirty | lo: ... | hi: ... | verdict
# promoted = bytes copied out of the nursery (minors and fulls); cards =
# dirty cards summed over the minors (the prototype marks a field's card on
# every store into an old object: gcsim's cards_any). ok when the minors and
# fulls equal the lower band's and the promoted bytes lie in the band (more
# promotion than the upper band is nepotism: dead old objects keeping young
# ones alive, which the simulator cannot see).
set -u
here=$(cd "$(dirname "$0")/../.." && pwd)
vm=""
out=tests/out/gcsim/vproto
nurseries="262144 1048576 4194304"
while [ $# -gt 0 ]; do
  case "$1" in
    --vm) vm=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --nurseries) nurseries=$2; shift 2 ;;
    *) break ;;
  esac
done
[ -n "$vm" ] || { echo "usage: tools/heapsim/validate-proto.sh --vm VM [--out DIR] [--nurseries \"N ...\"] TRACE..." >&2; exit 2; }
gcsim=$here/bin/gcsim
case "$vm" in /*) ;; *) vm=$(pwd)/$vm ;; esac   # it runs in the trace's directory
mkdir -p "$out"; out=$(cd "$out" && pwd)
status=0
for tr in "$@"; do
  name=$(basename "$tr")
  cwd=$(sed -n 's/^cwd //p' "$tr/DONE"); cmd=$(sed -n 's/^cmd //p' "$tr/DONE"); outf=$(sed -n 's/^out //p' "$tr/DONE")
  stdin=$(sed -n 's/^stdin //p' "$tr/DONE"); rbc=${cmd%% *}
  [ -n "$stdin" ] || { [ -f "${rbc%.rbc}.input" ] && stdin=${rbc%.rbc}.input; }
  [ -n "$stdin" ] || stdin=/dev/null
  for n in $nurseries; do
    log=$out/$name.$n.gclog
    [ -n "$outf" ] && rm -f "$outf"
    # shellcheck disable=SC2086
    (cd "$cwd" && ulimit -v 4194304 && timeout 1200 "$vm" --jit=off --nursery "$n" --gc-log "$log" $cmd < "$stdin" > "$out/$name.stdout" 2> "$out/$name.stderr")
    [ -s "$log" ] || { echo "FAIL $name $n: no log ($(head -c 200 "$out/$name.stderr"))"; status=1; continue; }
    st=$(awk '!/^#/ { if ($2=="minor") { m++; c+=$17 } else f++; p+=$12 } END {print m+0, f+0, p+0, c+0}' "$log")
    run() { "$gcsim" --max-mb 5000 --header --trace "$tr" --nursery "$n" --old copy --full appel --band "$1" |
            awk -F'\t' 'NR==1{for(i=1;i<=NF;i++)h[$i]=i;next}{print $h["minors"], $h["fulls"], $h["promoted"], $h["cards_any_total"]}'; }
    lo=$(run lo); hi=$(run hi)
    set -- $st; sm=$1; sf=$2; sp=$3; sc=$4
    set -- $lo; lm=$1; lf=$2; lp=$3; lc=$4
    set -- $hi; hm=$1; hf=$2; hp=$3; hc=$4
    mn=$lp; mx=$hp; [ "$hp" -lt "$lp" ] && { mn=$hp; mx=$lp; }
    between() { a=$2; b=$3; [ "$a" -gt "$b" ] && { a=$3; b=$2; }; [ "$1" -ge "$a" ] && [ "$1" -le "$b" ]; }
    if [ "$lm" = "$sm" ] && [ "$lf" = "$sf" ] && [ "$sp" -ge "$mn" ] && [ "$sp" -le "$mx" ]; then v=ok
    elif [ "$lm" = "$sm" ] && [ "$lf" = "$sf" ] && [ "$sp" -gt "$mx" ]; then v=nepotism
    elif between "$sm" "$lm" "$hm" && between "$sf" "$lf" "$hf"; then v=band
    else v=DIFF; status=1; fi
    pct=$(awk -v s="$sp" -v a="$mn" -v b="$mx" 'BEGIN{ m=(a+b)/2; if (m>0) printf "%+.2f%%", 100*(s-m)/m; else print "-" }')
    printf '%s\t%s\t| %s %s %s %s\t| %s %s %s %s\t| %s %s %s %s\t| %s\t%s\n' "$name" "$n" "$sm" "$sf" "$sp" "$sc" "$lm" "$lf" "$lp" "$lc" "$hm" "$hf" "$hp" "$hc" "$pct" "$v"
  done
done
exit $status
