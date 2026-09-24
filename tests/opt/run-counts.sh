#!/bin/sh
# The counts of --count, natively and on runevm (docs/plans/codegen.md, D6):
#   tests/opt/run-counts.sh [--vm BIN] [--native BIN] [-j N] RBC...
# Each program is run by both, with the arguments and the input its test
# gives it (the siblings of tests/lang: NAME.args, NAME.stdin), and must
# print the same line `runevm: count: ...` -- the instructions it executed,
# the bytes and objects it allocated -- and the same output, and end with
# the same status. The programs of the Basis Library suite are run in the
# directory of their test, as tests/basis/run-matrix.sh runs them.
set -u
vm=bin/runevm
native=bin/runevm-opt
jobs=""
one=""
while [ $# -gt 0 ]; do
  case $1 in
    --vm) vm=$2; shift 2 ;;
    --native) native=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    *) break ;;
  esac
done
cd "$(dirname "$0")/../.."
root=$(pwd)
case $vm in /*) ;; *) vm=$root/$vm ;; esac
case $native in /*) ;; *) native=$root/$native ;; esac
out=$root/tests/out/opt-counts
mkdir -p "$out"

# --one RBC: a line OK or FAIL ...
if [ -n "$one" ]; then
  rbc=$one
  name=$(echo "$rbc" | tr '/' '_')
  base=tests/lang/$(basename "$rbc" .rbc)
  args=""
  [ -f "$base.args" ] && args=$(cat "$base.args")
  stdin=/dev/null
  [ -f "$base.stdin" ] && stdin=$root/$base.stdin
  dir=$(dirname "$rbc")
  case $rbc in tests/out/matrix/*) ;; *) dir=$root ;; esac
  # shellcheck disable=SC2086
  (cd "$dir" && "$vm" --count "$root/$rbc" $args < "$stdin" > "$out/$name.vm.out" 2> "$out/$name.vm.err")
  vcode=$?
  # shellcheck disable=SC2086
  (cd "$dir" && "$native" --count "$root/$rbc" $args < "$stdin" > "$out/$name.opt.out" 2> "$out/$name.opt.err")
  ncode=$?
  if [ "$vcode" != "$ncode" ]; then echo "FAIL counts $rbc: exit status $ncode natively, $vcode on runevm"
  elif ! cmp -s "$out/$name.vm.out" "$out/$name.opt.out"; then echo "FAIL counts $rbc: the output differs (diff $out/$name.vm.out $out/$name.opt.out)"
  elif ! cmp -s "$out/$name.vm.err" "$out/$name.opt.err"; then echo "FAIL counts $rbc: the counts or standard error differ (diff $out/$name.vm.err $out/$name.opt.err)"
  else echo OK
  fi
  exit 0
fi

[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
results=$(printf '%s\n' "$@" | xargs -n 1 -P "$jobs" sh tests/opt/run-counts.sh --vm "$vm" --native "$native" --one)
n=$(printf '%s\n' "$results" | grep -c '^OK$')
failures=$(printf '%s\n' "$results" | grep -v '^OK$' | grep .)
[ -z "$failures" ] || printf '%s\n' "$failures"
echo "counts: $n programs agree with runevm, $(printf '%s\n' "$failures" | grep -c .) differ"
[ -z "$failures" ]
