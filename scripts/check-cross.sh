#!/bin/sh
# Verify that the MLton, SML/NJ, Poly/ML and (when built) self-hosted builds
# of the compiler produce byte-identical bytecode for every test program, the
# examples, and the compiler itself.
#   scripts/check-cross.sh [-j N]
# Programs are checked N at a time (default: all available CPUs), each by a
# worker, `check-cross.sh --one PROGRAM`, which writes its outcome to
# tests/out/cross/<name>.result.
set -u
jobs=""
one=""
while [ $# -gt 0 ]; do
  case "$1" in
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    *) echo "usage: scripts/check-cross.sh [-j N]" >&2; exit 2 ;;
  esac
done
cd "$(dirname "$0")/.."
out=tests/out/cross
mkdir -p "$out"
builds="mlton smlnj polyml"
[ -x bin/rune-boot ] && builds="$builds boot"

# check NAME SOURCE... : compile the sources with every build and compare;
# print OK or the failures.
check() {
  name=$1
  shift
  ok=1
  for c in $builds; do
    if ! "bin/rune-$c" "$@" -o "$out/$name.$c.rbc" 2> "$out/$name.$c.err"; then
      echo "FAIL $name: rune-$c failed: $(head -1 "$out/$name.$c.err")"
      ok=0
    fi
  done
  [ $ok = 1 ] || return
  for c in $builds; do
    if ! cmp -s "$out/$name.mlton.rbc" "$out/$name.$c.rbc"; then
      echo "FAIL $name: bytecode differs between the mlton and $c builds"
      return
    fi
  done
  echo OK
}

# A program is a source file, or `rune` for the compiler itself.
if [ -n "$one" ]; then
  case "$one" in
    # shellcheck disable=SC2046
    rune) check rune build/config.sml $(grep -v '^[[:space:]]*#' sources.txt | grep -v '^[[:space:]]*$') src/main/rune-main.sml ;;
    *) check "$(basename "$one" .sml)" "$one" ;;
  esac > "$out/$(basename "$one" .sml).result"
  exit 0
fi

[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
sources=""
for src in tests/lang/*.sml examples/*.sml; do
  [ -f "$src" ] && sources="$sources $src"
done

rm -f "$out"/*.result
# The compiler is the longest job, so it goes first.
# shellcheck disable=SC2086
printf '%s\n' rune $sources | xargs -n 1 -P "$jobs" sh scripts/check-cross.sh --one

status=0
count=0
for p in $sources rune; do
  name=$(basename "$p" .sml)
  result=$(cat "$out/$name.result" 2> /dev/null)
  if [ "$result" = OK ]; then
    count=$((count + 1))
  else
    [ -n "$result" ] || result="FAIL $name: no result"
    echo "$result"
    status=1
  fi
done

echo "check-cross: $count programs produce identical bytecode with all builds ($builds)"
exit $status
