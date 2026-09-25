#!/bin/sh
# vm/new's JIT against its interpreter (docs/plans/jit.md, M4): every
# program of tests/lang and tests/perf, compiled once to the register
# bytecode, run with --jit=off and with --jit=all, must print the same and
# report the same counts of --count -- instructions, bytes and objects --
# since the code the JIT makes counts every instruction the loop would and
# allocates every object it would (docs/native.md, The contract). So must
# tests/opt/prims.sml, the primitives on their edge cases.
#   scripts/check-jit.sh [--rune BIN] [--vm BIN] [-j N]
set -u
cd "$(dirname "$0")/.."
rune=bin/rune-new
vm=bin/runevm-new
jobs=$(sh scripts/ncpus.sh)
one=""
while [ $# -gt 0 ]; do
  case "$1" in
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    *) echo "usage: scripts/check-jit.sh [--rune BIN] [--vm BIN] [-j N]" >&2; exit 2 ;;
  esac
done
out=tests/out/jit-check
mkdir -p "$out"

# --one BASE: one program, BASE without .sml; prints a line when it fails
if [ -n "$one" ]; then
  name=$(echo "$one" | tr '/' '_')
  args=""; [ -f "$one.args" ] && args=$(cat "$one.args")
  vmargs=""; [ -f "$one.vmargs" ] && vmargs=$(cat "$one.vmargs")
  stdin=/dev/null; [ -f "$one.stdin" ] && stdin=$one.stdin
  mkdir -p "$out/$name"
  root=$(pwd)
  case $stdin in /*) ;; *) stdin=$root/$stdin ;; esac
  if ! "$rune" "$one.sml" -o "$out/$name/prog.rbc" 2> "$out/$name/cerr"; then
    echo "FAIL jit.$name: $(grep -m1 . "$out/$name/cerr")"; exit 0
  fi
  "$vm" --disasm "$out/$name/prog.rbc" > "$out/$name/disasm" 2> /dev/null
  for mode in off all; do
    # shellcheck disable=SC2086
    (cd "$out/$name" && "$root/$vm" --count --jit=$mode $vmargs prog.rbc $args < "$stdin" > "stdout.$mode" 2> "stderr.$mode")
    echo "exit $?" >> "$out/$name/stderr.$mode"
    sed -n 's/^runevm: count: //p' "$out/$name/stderr.$mode" > "$out/$name/count.$mode"
  done
  if ! cmp -s "$out/$name/stdout.off" "$out/$name/stdout.all"; then
    echo "FAIL jit.$name: prints differently under --jit=all: $(diff "$out/$name/stdout.off" "$out/$name/stdout.all" | head -2 | tail -1)"
  elif ! cmp -s "$out/$name/count.off" "$out/$name/count.all"; then
    echo "FAIL jit.$name: counts $(cat "$out/$name/count.off") interpreted, $(cat "$out/$name/count.all") under --jit=all"
  elif ! cmp -s "$out/$name/stderr.off" "$out/$name/stderr.all"; then
    echo "FAIL jit.$name: standard error differs under --jit=all: $(diff "$out/$name/stderr.off" "$out/$name/stderr.all" | head -2 | tail -1)"
  fi
  exit 0
fi

progs=$(ls tests/lang/*.sml tests/perf/*.sml | sed 's/\.sml$//'; echo tests/opt/prims)
n=$(echo "$progs" | wc -l | tr -d ' ')
fails=$(echo "$progs" | xargs -P "$jobs" -I{} sh "$0" --rune "$rune" --vm "$vm" --one {})

# the program of every instruction (tests/new/every-opcode.rasm), which the
# compiler never writes whole: assembled, run both ways, and its output
# and counts compared
mkdir -p "$out/every-opcode"
printf "$(awk -v opdefs=vm/new/regs.def -v primdefs=vm/prims.def -f tests/opt/rbcasm.awk tests/new/every-opcode.rasm)" > "$out/every-opcode/prog.rbc"
"$vm" --disasm "$out/every-opcode/prog.rbc" > "$out/every-opcode/disasm" 2> /dev/null
for mode in off all; do
  "$vm" --count --jit=$mode "$out/every-opcode/prog.rbc" > "$out/every-opcode/stdout.$mode" 2> "$out/every-opcode/stderr.$mode"
  echo "exit $?" >> "$out/every-opcode/stderr.$mode"
done
if ! cmp -s "$out/every-opcode/stdout.off" "$out/every-opcode/stdout.all" || ! cmp -s "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.all"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/new/every-opcode.rasm differs between --jit=off and --jit=all: $(diff "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.all" | head -2 | tail -1)"
elif ! grep -q "^exit 0" "$out/every-opcode/stderr.off"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/new/every-opcode.rasm fails: $(head -1 "$out/every-opcode/stderr.off")"
fi
n=$((n + 1))
# every instruction of the register set occurs in those programs, so
# that every emitter is run by them
missing=""
for op in $(awk '!/^#/ && NF { print $1 }' vm/new/regs.def); do
  if ! grep -q -l "^ *[0-9]*  $op\b" "$out"/*/disasm 2> /dev/null; then missing="$missing $op"; fi
done
if [ -n "$missing" ]; then
  echo "FAIL jit.every-instruction: no program of tests/lang or tests/perf has$missing"
  fails="$fails${fails:+
}FAIL jit.every-instruction"
fi

if [ -n "$fails" ]; then
  echo "$fails"
  echo "check-jit: $(echo "$fails" | grep -c FAIL) of $n programs differ between --jit=off and --jit=all"
  exit 1
fi
echo "check-jit: $n programs print and count the same under --jit=off and --jit=all, and use every instruction"
