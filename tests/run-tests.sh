#!/bin/sh
# Rune test runner.
#   tests/run-tests.sh [--rune BIN] [--vm BIN] [--update] [FILTER]
#
# tests/lang/<id>_<name>.sml : compiled and run; stdout must equal the
#   matching .expected file. Optional siblings: .args (command line words for
#   the program), .vmargs (options for runevm), .stdin (fed to the program),
#   .exitcode (expected status, default 0), .stderr (expected stderr, compared
#   exactly when present).
# tests/errors/<id>_<name>.sml : must fail to compile; the first line of the
#   compiler's stderr must contain the text in the .expected file.
set -u

rune=bin/rune
vm=bin/runevm
update=0
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    --update) update=1; shift ;;
    *) filter=$1; shift ;;
  esac
done

cd "$(dirname "$0")/.."
out=tests/out
mkdir -p "$out"
pass=0
fail=0
failed=""

report_fail() {
  fail=$((fail + 1))
  failed="$failed $1"
  echo "FAIL $1: $2"
}

for src in tests/lang/*.sml; do
  name=$(basename "$src" .sml)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  base=tests/lang/$name
  rbc=$out/$name.rbc
  if ! "$rune" "$src" -o "$rbc" 2> "$out/$name.cerr"; then
    report_fail "$name" "compile error: $(head -1 "$out/$name.cerr")"
    continue
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
    echo "updated $name"
    continue
  fi
  if [ "$code" != "$expected_code" ]; then
    report_fail "$name" "exit code $code, expected $expected_code: $(head -1 "$out/$name.stderr")"
    continue
  fi
  if [ ! -f "$base.expected" ]; then
    report_fail "$name" "missing $base.expected"
    continue
  fi
  if ! cmp -s "$out/$name.stdout" "$base.expected"; then
    report_fail "$name" "stdout differs (diff $base.expected $out/$name.stdout)"
    continue
  fi
  if [ -f "$base.stderr" ] && ! cmp -s "$out/$name.stderr" "$base.stderr"; then
    report_fail "$name" "stderr differs (diff $base.stderr $out/$name.stderr)"
    continue
  fi
  pass=$((pass + 1))
done

for src in tests/errors/*.sml; do
  [ -f "$src" ] || continue
  name=$(basename "$src" .sml)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  base=tests/errors/$name
  if "$rune" "$src" -o "$out/$name.rbc" 2> "$out/$name.cerr"; then
    report_fail "$name" "expected a compile error but compilation succeeded"
    continue
  fi
  if [ "$update" = 1 ]; then
    head -1 "$out/$name.cerr" | sed 's/^[^ ]* error: //' > "$base.expected"
    echo "updated $name"
    continue
  fi
  if [ ! -f "$base.expected" ]; then
    report_fail "$name" "missing $base.expected"
    continue
  fi
  if ! head -1 "$out/$name.cerr" | grep -qF "$(cat "$base.expected")"; then
    report_fail "$name" "error message mismatch: $(head -1 "$out/$name.cerr")"
    continue
  fi
  pass=$((pass + 1))
done

echo "passed $pass, failed $fail"
[ -n "$failed" ] && echo "failed:$failed"
[ "$fail" = 0 ]
