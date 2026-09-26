#!/bin/sh
# vm/new's JIT against its interpreter (docs/plans/jit.md, M4): every
# program of tests/lang and tests/perf, compiled once to the register
# bytecode, run with --jit=off and with --jit=all, must print the same and
# report the same counts of --count -- instructions, bytes and objects --
# since the code the JIT makes counts every instruction the loop would and
# allocates every object it would (docs/native.md, The contract). So must
# tests/opt/prims.sml, the primitives on their edge cases. A third run
# compiles every other function (--jit-only=odd, M5), so that calls,
# returns and raises cross between the tiers both ways.
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
  for mode in off all odd; do
    jit="--jit=$mode"; [ "$mode" = odd ] && jit="--jit=all --jit-only=odd"
    # shellcheck disable=SC2086
    (cd "$out/$name" && "$root/$vm" --count $jit $vmargs prog.rbc $args < "$stdin" > "stdout.$mode" 2> "stderr.$mode")
    echo "exit $?" >> "$out/$name/stderr.$mode"
    sed -n 's/^runevm: count: //p' "$out/$name/stderr.$mode" > "$out/$name/count.$mode"
  done
  for mode in all odd; do
    what="--jit=all"; [ "$mode" = odd ] && what="every other function compiled"
    if ! cmp -s "$out/$name/stdout.off" "$out/$name/stdout.$mode"; then
      echo "FAIL jit.$name: prints differently with $what: $(diff "$out/$name/stdout.off" "$out/$name/stdout.$mode" | head -2 | tail -1)"
    elif ! cmp -s "$out/$name/count.off" "$out/$name/count.$mode"; then
      echo "FAIL jit.$name: counts $(cat "$out/$name/count.off") interpreted, $(cat "$out/$name/count.$mode") with $what"
    elif ! cmp -s "$out/$name/stderr.off" "$out/$name/stderr.$mode"; then
      echo "FAIL jit.$name: standard error differs with $what: $(diff "$out/$name/stderr.off" "$out/$name/stderr.$mode" | head -2 | tail -1)"
    fi
  done
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
for mode in off all odd; do
  jit="--jit=$mode"; [ "$mode" = odd ] && jit="--jit=all --jit-only=odd"
  # shellcheck disable=SC2086
  "$vm" --count $jit "$out/every-opcode/prog.rbc" > "$out/every-opcode/stdout.$mode" 2> "$out/every-opcode/stderr.$mode"
  echo "exit $?" >> "$out/every-opcode/stderr.$mode"
done
if ! cmp -s "$out/every-opcode/stdout.off" "$out/every-opcode/stdout.all" || ! cmp -s "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.all"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/new/every-opcode.rasm differs between --jit=off and --jit=all: $(diff "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.all" | head -2 | tail -1)"
elif ! cmp -s "$out/every-opcode/stdout.off" "$out/every-opcode/stdout.odd" || ! cmp -s "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.odd"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/new/every-opcode.rasm differs with every other function compiled: $(diff "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.odd" | head -2 | tail -1)"
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

# the compiler as register bytecode compiling itself (M5): the same bytes
# and the same counts under every mode
mkdir -p "$out/bootstrap"
srcs="build/config.sml $(grep -v '^#' sources.txt | tr '\n' ' ') src/main/rune-main.sml"
# shellcheck disable=SC2086
if ! "$rune" -o "$out/bootstrap/rune.rbc" $srcs 2> "$out/bootstrap/cerr"; then
  fails="$fails${fails:+
}FAIL jit.bootstrap: the compiler does not compile to the register bytecode: $(head -1 "$out/bootstrap/cerr")"
else
  for mode in off all odd; do
    jit="--jit=$mode"; [ "$mode" = odd ] && jit="--jit=all --jit-only=odd"
    # shellcheck disable=SC2086
    "$vm" --count $jit --heap-size 67108864 "$out/bootstrap/rune.rbc" --lib lib -o "$out/bootstrap/by.$mode.rbc" $srcs 2> "$out/bootstrap/stderr.$mode"
    echo "exit $?" >> "$out/bootstrap/stderr.$mode"
  done
  for mode in all odd; do
    what="--jit=all"; [ "$mode" = odd ] && what="every other function compiled"
    if ! cmp -s "$out/bootstrap/by.off.rbc" "$out/bootstrap/by.$mode.rbc"; then
      fails="$fails${fails:+
}FAIL jit.bootstrap: the compiler makes other bytecode with $what"
    elif ! cmp -s "$out/bootstrap/stderr.off" "$out/bootstrap/stderr.$mode"; then
      fails="$fails${fails:+
}FAIL jit.bootstrap: the compiler counts differently with $what: $(diff "$out/bootstrap/stderr.off" "$out/bootstrap/stderr.$mode" | head -2 | tail -1)"
    fi
  done
fi
n=$((n + 1))

if [ -n "$fails" ]; then
  echo "$fails"
  echo "check-jit: $(echo "$fails" | grep -c FAIL) of $n programs differ between --jit=off and --jit=all"
  exit 1
fi
echo "check-jit: $n programs print and count the same under --jit=off, --jit=all and with every other function compiled, and use every instruction"
