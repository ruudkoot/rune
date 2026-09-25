#!/bin/sh
# Rune test runner.
#   tests/run-tests.sh [--rune BIN] [--vm BIN] [--out DIR] [--skip FILE] [--update] [-j N] [FILTER]
#
# tests/lang/<id>_<name>.sml : compiled and run; stdout must equal the
#   matching .expected file. Optional siblings: .args (command line words for
#   the program), .vmargs (options for runevm), .stdin (fed to the program),
#   .restore (the standard output of `runevm --restore` on the image the
#   program wrote to tests/out/NAME.img with Runtime.save),
#   .exitcode (expected status, default 0), .stderr (expected stderr, compared
#   exactly when present), .cwarn (expected compiler stderr, i.e. warnings,
#   compared exactly when present; otherwise the compiler must print nothing).
# tests/errors/<id>_<name>.sml : must fail to compile; the first line of the
#   compiler's stderr must contain the text in the .expected file.
#
# Tests run N at a time (default: all available CPUs); results are reported
# in file order. Each test runs in a worker, `run-tests.sh ... --one SRC`,
# which writes its outcome to tests/out/<name>.result.
set -u
# The same time zone on every machine (tests/basis/run-matrix.sh says why).
TZ='NST3:30NDT,M3.2.0,M11.1.0'
export TZ

rune=bin/rune
vm=bin/runevm
skip=""
outdir=tests/out
update=0
jobs=""
one=""
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    --update) update=1; shift ;;
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    --skip) skip=$2; shift 2 ;;
    --out) outdir=$2; shift 2 ;;
    *) filter=$1; shift ;;
  esac
done

cd "$(dirname "$0")/.."
# where the bytecode and what each run printed go (--out, for a second VM
# whose runs must not take the place of runevm's); an image goes where the
# program writes it, tests/out/NAME.img
out=$outdir
img=tests/out
mkdir -p "$out" "$img"

# run_lang NAME / run_error NAME: run one test and print its outcome: PASS,
# "FAIL NAME: why" or "updated NAME".
run_lang() {
  name=$1
  base=tests/lang/$name
  rbc=$out/$name.rbc
  if ! "$rune" "$base.sml" -o "$rbc" 2> "$out/$name.cerr"; then
    echo "FAIL $name: compile error: $(head -1 "$out/$name.cerr")"
    return
  fi
  args=""
  [ -f "$base.args" ] && args=$(cat "$base.args")
  vmargs=""
  [ -f "$base.vmargs" ] && vmargs=$(cat "$base.vmargs")
  stdin=/dev/null
  [ -f "$base.stdin" ] && stdin=$base.stdin
  expected_code=0
  [ -f "$base.exitcode" ] && expected_code=$(cat "$base.exitcode")
  # shellcheck disable=SC2086
  "$vm" $vmargs "$rbc" $args < "$stdin" > "$out/$name.stdout" 2> "$out/$name.stderr"
  code=$?
  if [ "$update" = 1 ]; then
    cp "$out/$name.stdout" "$base.expected"
    [ -f "$base.cwarn" ] && cp "$out/$name.cerr" "$base.cwarn"
    echo "updated $name"
    return
  fi
  if [ -f "$base.cwarn" ]; then
    if ! cmp -s "$out/$name.cerr" "$base.cwarn"; then
      echo "FAIL $name: compiler warnings differ (diff $base.cwarn $out/$name.cerr)"
      return
    fi
  elif [ -s "$out/$name.cerr" ]; then
    echo "FAIL $name: unexpected compiler output: $(head -1 "$out/$name.cerr")"
    return
  fi
  if [ "$code" != "$expected_code" ]; then
    echo "FAIL $name: exit code $code, expected $expected_code: $(head -1 "$out/$name.stderr")"
    return
  fi
  if [ ! -f "$base.expected" ]; then
    echo "FAIL $name: missing $base.expected"
    return
  fi
  if ! cmp -s "$out/$name.stdout" "$base.expected"; then
    echo "FAIL $name: stdout differs (diff $base.expected $out/$name.stdout)"
    return
  fi
  if [ -f "$base.stderr" ] && ! cmp -s "$out/$name.stderr" "$base.stderr"; then
    echo "FAIL $name: stderr differs (diff $base.stderr $out/$name.stderr)"
    return
  fi
  # A program that writes itself to $out/$name.img with Runtime.save is
  # carried on by a second VM, whose standard output is the .restore file.
  # It takes two runs of the VM, which nothing else here does.
  if [ -f "$base.restore" ]; then
    if [ ! -f "$img/$name.img" ]; then
      echo "FAIL $name: no $img/$name.img to restore"
      return
    fi
    "$vm" --restore "$img/$name.img" < /dev/null > "$out/$name.restored" 2> "$out/$name.restored.err"
    rcode=$?
    if [ "$rcode" != 0 ]; then
      echo "FAIL $name: --restore exited $rcode: $(head -1 "$out/$name.restored.err")"
      return
    fi
    if ! cmp -s "$out/$name.restored" "$base.restore"; then
      echo "FAIL $name: restored stdout differs (diff $base.restore $out/$name.restored)"
      return
    fi
  fi
  echo PASS
}

run_error() {
  name=$1
  base=tests/errors/$name
  if "$rune" "$base.sml" -o "$out/$name.rbc" 2> "$out/$name.cerr"; then
    echo "FAIL $name: expected a compile error but compilation succeeded"
    return
  fi
  if [ "$update" = 1 ]; then
    head -1 "$out/$name.cerr" | sed 's/^[^ ]* error: //' > "$base.expected"
    echo "updated $name"
    return
  fi
  if [ ! -f "$base.expected" ]; then
    echo "FAIL $name: missing $base.expected"
    return
  fi
  if ! head -1 "$out/$name.cerr" | grep -qF "$(cat "$base.expected")"; then
    echo "FAIL $name: error message mismatch: $(head -1 "$out/$name.cerr")"
    return
  fi
  echo PASS
}

if [ -n "$one" ]; then
  name=$(basename "$one" .sml)
  case "$one" in
    tests/lang/*) run_lang "$name" ;;
    *) run_error "$name" ;;
  esac > "$out/$name.result"
  exit 0
fi

[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
# A skip file names the programs to leave out, one to a line, with a reason
# after the name; a line beginning with # is a comment. Only a runner that
# gives the VM of another machine uses it (tests/run-portability.sh).
skipped=""
nskip=0
if [ -n "$skip" ]; then
  skipped=$(sed -e 's/#.*//' -e 's/[[:space:]].*//' "$skip" | grep -v '^$' | tr '\n' ' ')
fi
is_skipped() { case " $skipped " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

tests=""
for src in tests/lang/*.sml tests/errors/*.sml; do
  [ -f "$src" ] || continue
  name=$(basename "$src" .sml)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  if is_skipped "$name"; then nskip=$((nskip + 1)); continue; fi
  tests="$tests $src"
done

rm -f "$out"/*.result
upd=""
[ "$update" = 1 ] && upd=--update
if [ -n "$tests" ]; then
  # shellcheck disable=SC2086
  printf '%s\n' $tests |
    xargs -n 1 -P "$jobs" sh tests/run-tests.sh --rune "$rune" --vm "$vm" --out "$out" $upd --one
fi

pass=0
fail=0
failed=""
for src in $tests; do
  name=$(basename "$src" .sml)
  result=$(cat "$out/$name.result" 2> /dev/null)
  case "$result" in
    PASS) pass=$((pass + 1)) ;;
    "updated $name") echo "$result" ;;
    *)
      [ -n "$result" ] || result="FAIL $name: no result"
      echo "$result"
      fail=$((fail + 1))
      failed="$failed $name"
      ;;
  esac
done

if [ "$nskip" -gt 0 ]; then echo "passed $pass, failed $fail, skipped $nskip"
else echo "passed $pass, failed $fail"
fi
[ -n "$failed" ] && echo "failed:$failed"
[ "$fail" = 0 ]
