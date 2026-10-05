#!/bin/sh
# runtime/register's JIT against its interpreter (docs/plans/jit.md, M4): every
# program of tests/lang and tests/perf, compiled once to the register
# bytecode, run with --jit=off and with --jit=all, must print the same and
# report the same counts of --count -- instructions, bytes and objects --
# since the code the JIT makes counts every instruction the loop would and
# allocates every object it would (docs/native.md, The contract). So must
# tests/opt/prims.sml, the primitives on their edge cases. A third run
# compiles every other function (--jit-only=odd, M5), so that calls,
# returns and raises cross between the tiers both ways; a fourth tiers
# up by the counters with the lowest thresholds and invalidates the
# callee's code at every fifth call into it (--jit=baseline --jit-calls=1
# --jit-work=1 --jit-stress=5, M6), so that frames pushed interpreted
# return into code, loops are entered mid-way, and frames that would
# return into dead code return to the interpreter. A fifth compiles every
# function at tier 2 (--jit=all --jit-tier=2, M9), whose code keeps
# values in machine registers, a sixth every other one at tier 2, and a
# seventh leaves the code for the interpreter after every instruction
# (--deopt-stress=1, M11), so that the frame is exact at every boundary.
# An eighth counts what tier 2's code calls and branches on (--jit-profile),
# whose helper is called in the middle of a call through a closure, with
# what the call found and the homes kept around it.
#   scripts/check-jit.sh [--rune BIN] [--vm BIN] [-j N]
set -u
cd "$(dirname "$0")/.."
rune=bin/rune
vm=bin/runevm
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
out=tests/out/jit-check-$(basename "$vm")
mkdir -p "$out"
# a run that never ends (code that loops, or a compile that does) is
# stopped after ten minutes where the system has timeout, so that the
# oracle reports it rather than waiting
limit=""
command -v timeout > /dev/null 2>&1 && limit="timeout 600"

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
  for mode in off all odd stress opt optodd deopt profile; do
    jit="--jit=$mode"
    [ "$mode" = odd ] && jit="--jit=all --jit-only=odd"
    [ "$mode" = stress ] && jit="--jit=baseline --jit-calls=1 --jit-work=1 --jit-stress=5"
    [ "$mode" = opt ] && jit="--jit=all --jit-tier=2"
    [ "$mode" = optodd ] && jit="--jit=all --jit-only=odd --jit-tier=2"
    [ "$mode" = deopt ] && jit="--jit=all --jit-tier=2 --deopt-stress=1"
    [ "$mode" = profile ] && jit="--jit=all --jit-tier=2 --jit-profile"
    # shellcheck disable=SC2086
    (cd "$out/$name" && $limit "$root/$vm" --count $jit $vmargs prog.rbc $args < "$stdin" > "stdout.$mode" 2> "stderr.$mode")
    echo "exit $?" >> "$out/$name/stderr.$mode"
    sed -n 's/^runevm: count: //p' "$out/$name/stderr.$mode" > "$out/$name/count.$mode"
  done
  for mode in all odd stress opt optodd deopt profile; do
    what="--jit=all"
    [ "$mode" = odd ] && what="every other function compiled"
    [ "$mode" = stress ] && what="tiering up and invalidating (--jit-stress)"
    [ "$mode" = opt ] && what="every function at tier 2 (--jit-tier=2)"
    [ "$mode" = optodd ] && what="every other function at tier 2"
    [ "$mode" = deopt ] && what="leaving for the interpreter after every instruction (--deopt-stress=1)"
    [ "$mode" = profile ] && what="tier 2 counting its calls and branches (--jit-profile)"
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

# the program of every instruction (tests/register/every-opcode.rasm), which the
# compiler never writes whole: assembled, run both ways, and its output
# and counts compared
mkdir -p "$out/every-opcode"
printf "$(awk -v opdefs=runtime/register/regs.def -v primdefs=runtime/prims.def -f tests/opt/rbcasm.awk tests/register/every-opcode.rasm)" > "$out/every-opcode/prog.rbc"
"$vm" --disasm "$out/every-opcode/prog.rbc" > "$out/every-opcode/disasm" 2> /dev/null
for mode in off all odd stress opt deopt; do
  jit="--jit=$mode"
  [ "$mode" = odd ] && jit="--jit=all --jit-only=odd"
  [ "$mode" = stress ] && jit="--jit=baseline --jit-calls=1 --jit-work=1 --jit-stress=5"
  [ "$mode" = opt ] && jit="--jit=all --jit-tier=2"
  [ "$mode" = deopt ] && jit="--jit=all --jit-tier=2 --deopt-stress=1"
  # shellcheck disable=SC2086
  "$vm" --count $jit "$out/every-opcode/prog.rbc" > "$out/every-opcode/stdout.$mode" 2> "$out/every-opcode/stderr.$mode"
  echo "exit $?" >> "$out/every-opcode/stderr.$mode"
done
if ! cmp -s "$out/every-opcode/stdout.off" "$out/every-opcode/stdout.all" || ! cmp -s "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.all"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/register/every-opcode.rasm differs between --jit=off and --jit=all: $(diff "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.all" | head -2 | tail -1)"
elif ! cmp -s "$out/every-opcode/stdout.off" "$out/every-opcode/stdout.odd" || ! cmp -s "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.odd"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/register/every-opcode.rasm differs with every other function compiled: $(diff "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.odd" | head -2 | tail -1)"
elif ! cmp -s "$out/every-opcode/stdout.off" "$out/every-opcode/stdout.stress" || ! cmp -s "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.stress"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/register/every-opcode.rasm differs under --jit-stress: $(diff "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.stress" | head -2 | tail -1)"
elif ! cmp -s "$out/every-opcode/stdout.off" "$out/every-opcode/stdout.opt" || ! cmp -s "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.opt"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/register/every-opcode.rasm differs at tier 2: $(diff "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.opt" | head -2 | tail -1)"
elif ! cmp -s "$out/every-opcode/stdout.off" "$out/every-opcode/stdout.deopt" || ! cmp -s "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.deopt"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/register/every-opcode.rasm differs under --deopt-stress: $(diff "$out/every-opcode/stderr.off" "$out/every-opcode/stderr.deopt" | head -2 | tail -1)"
elif ! grep -q "^exit 0" "$out/every-opcode/stderr.off"; then
  fails="$fails${fails:+
}FAIL jit.every-opcode: tests/register/every-opcode.rasm fails: $(head -1 "$out/every-opcode/stderr.off")"
fi
n=$((n + 1))
# the fatal errors of compiled code, which a typed program never reaches
# and the suites above never do: programs that do (tests/register/fatal-*.rasm),
# each in a function the JIT compiles, run with --checked, must stop with
# the interpreter's message, trace and status at both tiers -- the code
# goes to one stub of the region with the number of a record (compile.c,
# jit_fatal), and the record has what the message says
for f in tests/register/fatal-*.rasm; do
  b=$(basename "$f" .rasm)
  mkdir -p "$out/$b"
  printf "$(awk -v opdefs=runtime/register/regs.def -v primdefs=runtime/prims.def -f tests/opt/rbcasm.awk "$f")" > "$out/$b/prog.rbc"
  for mode in off all opt; do
    jit="--jit=$mode"; [ "$mode" = opt ] && jit="--jit=all --jit-tier=2"
    # shellcheck disable=SC2086
    "$vm" --checked $jit "$out/$b/prog.rbc" > "$out/$b/stdout.$mode" 2> "$out/$b/stderr.$mode"
    echo "exit $?" >> "$out/$b/stderr.$mode"
  done
  if ! grep -q "fatal error at pc" "$out/$b/stderr.off"; then
    fails="$fails${fails:+
}FAIL jit.$b: $f does not reach its fatal error: $(head -1 "$out/$b/stderr.off")"
  fi
  for mode in all opt; do
    if ! cmp -s "$out/$b/stdout.off" "$out/$b/stdout.$mode" || ! cmp -s "$out/$b/stderr.off" "$out/$b/stderr.$mode"; then
      fails="$fails${fails:+
}FAIL jit.$b: $f stops differently with --jit=$mode: $(diff "$out/$b/stderr.off" "$out/$b/stderr.$mode" | head -2 | tail -1)"
    fi
  done
  n=$((n + 1))
done
# every instruction of the register set occurs in those programs, so
# that every emitter is run by them
missing=""
for op in $(awk '!/^#/ && NF { print $1 }' runtime/register/regs.def); do
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
  # baseline with the default thresholds too: the mode make check runs in;
  # and tier 2 for every function (M9)
  for mode in off all odd baseline opt deopt; do
    jit="--jit=$mode"; [ "$mode" = odd ] && jit="--jit=all --jit-only=odd"
    [ "$mode" = opt ] && jit="--jit=all --jit-tier=2"
    [ "$mode" = deopt ] && jit="--jit=all --jit-tier=2 --deopt-stress=7"
    # The driver now reads and protects its output path. Use one path and
    # the same initial filesystem state so its work is identical in each mode.
    rm -f "$out/bootstrap/compiled.rbc" "$out/bootstrap/by.$mode.rbc"
    # shellcheck disable=SC2086
    "$vm" --count $jit --heap-size 67108864 "$out/bootstrap/rune.rbc" --lib lib -o "$out/bootstrap/compiled.rbc" $srcs 2> "$out/bootstrap/stderr.$mode"
    echo "exit $?" >> "$out/bootstrap/stderr.$mode"
    [ ! -f "$out/bootstrap/compiled.rbc" ] || cp "$out/bootstrap/compiled.rbc" "$out/bootstrap/by.$mode.rbc"
  done
  for mode in all odd baseline opt deopt; do
    what="--jit=$mode"; [ "$mode" = odd ] && what="every other function compiled"
    [ "$mode" = opt ] && what="every function at tier 2"
    [ "$mode" = deopt ] && what="leaving for the interpreter at every seventh instruction (--deopt-stress=7)"
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
echo "check-jit: $n programs print and count the same under --jit=off, --jit=all, with every other function compiled, under --jit-stress, at tier 2 and under --deopt-stress, and use every instruction"
