#!/bin/sh
# Verify that the MLton, SML/NJ (64- and 32-bit), Poly/ML and (when built)
# self-hosted builds of the compiler produce byte-identical bytecode for every test program, the
# examples, the programs of the Basis Library suite, the compiler itself and
# runedoc, and that the builds of runedoc (scripts/check-doc-cross.sh) write
# the same documentation.
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
builds="mlton smlnj smlnj32 polyml"
[ -x bin/rune-boot ] && builds="$builds boot"

# check NAME SOURCE... : compile the sources with every build and compare;
# print OK or the failures. With may_fail=1 the program may be one that Rune
# rejects (a test of the Basis Library suite that uses a member Rune lacks);
# then every build must reject it with the same messages.
check() {
  name=$1
  shift
  failed=""
  for c in $builds; do
    "bin/rune-$c" "$@" -o "$out/$name.$c.rbc" 2> "$out/$name.$c.err" || failed="$failed $c"
  done
  if [ -n "$failed" ]; then
    if [ "$may_fail" = 1 ] && [ "$failed" = " $builds" ]; then
      for c in $builds; do
        if ! cmp -s "$out/$name.mlton.err" "$out/$name.$c.err"; then
          echo "FAIL $name: the mlton and $c builds reject the program differently"
          return
        fi
      done
      echo OK
      return
    fi
    for c in $failed; do
      echo "FAIL $name: rune-$c failed: $(head -1 "$out/$name.$c.err")"
    done
    return
  fi
  for c in $builds; do
    if ! cmp -s "$out/$name.mlton.rbc" "$out/$name.$c.rbc"; then
      echo "FAIL $name: bytecode differs between the mlton and $c builds"
      return
    fi
  done
  echo OK
}

# A program is a source file, `basis:TEST` for the program of the Basis
# Library suite that runs tests/basis/TEST.sml, `basis-all` for a program
# compiled with every file of the basis library (--basis all), `rune` for
# the compiler itself, or `runedoc` for the documentation generator.
result_name() {
  case "$1" in
    basis:*) echo "basis-${1#basis:}" ;;
    basis-all) echo basis-all ;;
    *) basename "$1" .sml ;;
  esac
}

if [ -n "$one" ]; then
  may_fail=0
  case "$one" in
    # shellcheck disable=SC2046
    rune) check rune build/config.sml $(grep -v '^[[:space:]]*#' sources.txt | grep -v '^[[:space:]]*$') src/main/rune-main.sml ;;
    # shellcheck disable=SC2046
    runedoc) check runedoc build/config.sml $(grep -v '^[[:space:]]*#' sources-doc.txt | grep -v '^[[:space:]]*$') src/main/runedoc-rune-main.sml ;;
    basis-all) check basis-all --basis all examples/hello.sml ;;
    basis:*)
      may_fail=1
      t=tests/basis/${one#basis:}.sml
      uses=""
      for u in $(sed -n 's/^(\* uses: \(.*\) \*)$/\1/p' "$t"); do uses="$uses tests/basis/$u"; done
      # shellcheck disable=SC2086
      check "$(result_name "$one")" tests/basis/harness.sml $uses "$t" tests/basis/finish.sml
      ;;
    *) check "$(result_name "$one")" "$one" ;;
  esac > "$out/$(result_name "$one").result"
  exit 0
fi

[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
sources=""
for src in tests/lang/*.sml examples/*.sml; do
  [ -f "$src" ] && sources="$sources $src"
done
for src in tests/basis/*.sml; do
  case "$(basename "$src")" in harness.sml|finish.sml) continue ;; esac
  sources="$sources basis:$(basename "$src" .sml)"
done

rm -f "$out"/*.result
# The compiler is the longest job, so it goes first.
# shellcheck disable=SC2086
sources="$sources basis-all"
printf '%s\n' rune runedoc $sources | xargs -n 1 -P "$jobs" sh scripts/check-cross.sh --one

status=0
count=0
for p in $sources rune runedoc; do
  name=$(result_name "$p")
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
sh scripts/check-doc-cross.sh || status=1
exit $status
