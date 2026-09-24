#!/bin/sh
# The tests of runeopt, the native code generator (docs/native.md):
#   tests/opt/run-opt-tests.sh [--runeopt BIN] [--rune BIN] [--vm BIN] [-j N]
# 1. Files it refuses: a file the loader of runevm refuses is refused with
#    the loader's message, and a file the loader accepts but whose code does
#    not keep what a translation relies on (docs/native.md, The contract)
#    with a message of its own;
#    runeopt exits with status 1 and runs nothing.
# 2. Every program of the compiler, of runedoc and of the suites that have
#    been run (tests/out, tests/out/matrix/rune) passes --check, and
#    --disasm prints what runevm --disasm prints. The VM prints a real
#    constant with C's %g and runeopt the text the file carries, so those
#    lines are compared through awk's printf, which is C's.
# 3. Programs translated: every-opcode.rasm, which runs every instruction of
#    vm/opcodes.def and must name each, and the examples and a few programs of
#    tests/perf, compiled by --rune. Each prints what it prints under runevm,
#    exits as it does there, and --count says the same.
# 4. Images: saved by runevm and carried on natively, and the other way round,
#    and one of another program, which native code refuses.
set -u
opt=bin/runeopt
rune=bin/rune
vm=bin/runevm
jobs=""
one=""
while [ $# -gt 0 ]; do
  case $1 in
    --runeopt) opt=$2; shift 2 ;;
    --rune) rune=$2; shift 2 ;;
    --vm) vm=$2; shift 2 ;;
    -j) jobs=$2; shift 2 ;;
    --one) one=$2; shift 2 ;;
    *) echo "usage: $0 [--runeopt BIN] [--rune BIN] [--vm BIN] [-j N]" >&2; exit 2 ;;
  esac
done
cd "$(dirname "$0")/../.."
case $opt in /*) ;; *) opt=$(pwd)/$opt ;; esac
case $vm in /*) ;; *) vm=$(pwd)/$vm ;; esac
case $rune in /*) ;; *) rune=$(pwd)/$rune ;; esac
out=tests/out/opt
mkdir -p "$out"

# --one FILE: the parity of one program, as a line OK or FAIL ...
if [ -n "$one" ]; then
  name=$(echo "$one" | tr '/' '_')
  if ! "$opt" --check "$one" > /dev/null 2> "$out/$name.check"; then
    echo "FAIL opt.check $one: $(head -1 "$out/$name.check")"
    exit 0
  fi
  "$opt" --disasm "$one" 2> "$out/$name.err" | awk -f tests/opt/real-g.awk > "$out/$name.opt"
  "$vm" --disasm "$one" > "$out/$name.vm" 2>&1
  if cmp -s "$out/$name.opt" "$out/$name.vm"; then echo OK
  else echo "FAIL opt.disasm $one: runeopt and runevm differ (diff $out/$name.opt $out/$name.vm)"; fi
  exit 0
fi

pass=0
fail=0

# refuse NAME MESSAGE FILE: runeopt --check FILE exits with 1 and says MESSAGE
refuse() {
  name=$1 message=$2 file=$3
  "$opt" --check "$file" > "$out/$name.stdout" 2> "$out/$name.stderr"
  code=$?
  if [ "$code" = 1 ] && grep -qF -- "$message" "$out/$name.stderr"; then
    pass=$((pass + 1))
  else
    echo "FAIL opt.$name: exit code $code, expected 1 and \"$message\": $(head -1 "$out/$name.stderr")"
    fail=$((fail + 1))
  fi
}

# The numbers of the file are little-endian; an i32 or u32 is four bytes.
header='RUNE\002\000\000\000'
zero='\000\000\000\000'
one='\001\000\000\000'
two='\002\000\000\000'
huge='\377\377\377\377'
nodebug="$zero$zero$zero"

# What the loader refuses (as tests/vm has it for runevm).
printf '' > "$out/empty.rbc"
refuse empty "not a Rune bytecode file" "$out/empty.rbc"
printf 'RUNE\001\000\000\000' > "$out/version1.rbc"
refuse version1 "unsupported bytecode version" "$out/version1.rbc"
printf "$header$one\\003\\360\\377\\377\\377" > "$out/string.rbc"
refuse string "bad string constant" "$out/string.rbc"
printf "$header$zero$zero$one$zero$one$huge" > "$out/name.rbc"
refuse name "bad function name" "$out/name.rbc"
printf "$header$zero$zero$one$zero$one$zero$huge" > "$out/code.rbc"
refuse code "truncated code" "$out/code.rbc"
# one function, whose one instruction is opcode 200
printf "$header$zero$zero$one$zero$one$zero$one\\310$nodebug" > "$out/opcode.rbc"
refuse opcode "invalid opcode 200 at 0" "$out/opcode.rbc"
# LOCAL 1 in a function of one local
printf "$header$zero$zero$one$zero$one$zero\\005\\000\\000\\000\\005$one$nodebug" > "$out/local.rbc"
refuse local "bad operand for LOCAL at 0" "$out/local.rbc"
# a line table entry past the code: dpc 9
printf "$header$zero$zero$one$zero$one$zero$one\\000$one\\001\\000\\000\\000a$one\\004\\000\\000\\000\\011\\000\\002\\002" > "$out/linepc.rbc"
refuse linepc "line table out of range" "$out/linepc.rbc"

# What the loader accepts and runeopt does not (the contract). Each is one function f
# of one local (or two, f and g), with no debug information.
# code BYTES LEN: a program of one function f whose code is BYTES, LEN long
code() {
  printf "$header$zero$zero$one$zero$one\\001\\000\\000\\000f$2$1$nodebug"
}
# SELF (8): a closure is pushed, and then the code ends
code '\010' "$one" > "$out/runs-off.rbc"
refuse runs-off "the code runs off the end of f" "$out/runs-off.rbc"
# POP (11), RET (21): nothing to pop but the locals
code '\013\025' "$two" > "$out/underflow.rbc"
refuse underflow "the stack underflows at 0 in f" "$out/underflow.rbc"
# CON0 1, JUMPIFNOT 11, UNIT, 11: UNIT, RET: one path reaches 11 with one
# value more than the other
code '\004\001\000\000\000\027\013\000\000\000\003\003\025' '\015\000\000\000' > "$out/join.rbc"
refuse join "the stack or the handlers differ on the paths into 11" "$out/join.rbc"
# PUSHHANDLER 7, UNIT, RET, 7: RET: the first RET leaves with the handler
code '\031\007\000\000\000\003\025\025' '\010\000\000\000' > "$out/handler-ret.rbc"
refuse handler-ret "a handler of the function is still installed at 6 in f" "$out/handler-ret.rbc"
# POPHANDLER (26), UNIT, RET
code '\032\003\025' '\003\000\000\000' > "$out/pophandler.rbc"
refuse pophandler "POPHANDLER without a handler of the function at 0 in f" "$out/pophandler.rbc"
# INT 2^30, RET: an immediate the compiler never writes
code '\002\000\000\000\100\025' '\006\000\000\000' > "$out/immediate.rbc"
refuse immediate "an operand at 0 is out of range" "$out/immediate.rbc"
# two functions, f at 0: JUMP 5, and g at 5: UNIT, RET: f's jump is into g
printf "$header$zero$zero$two$zero$one\\001\\000\\000\\000f\\005\\000\\000\\000$one\\001\\000\\000\\000g\\007\\000\\000\\000\\026\\005\\000\\000\\000\\003\\025$nodebug" > "$out/leave.rbc"
refuse leave "a jump leaves its function at 0 in f" "$out/leave.rbc"
# two functions at offset 0: f has no code
printf "$header$zero$zero$two$zero$one\\001\\000\\000\\000f$zero$one\\001\\000\\000\\000g$two\\003\\025$nodebug" > "$out/empty-function.rbc"
refuse empty-function "function f has no code" "$out/empty-function.rbc"

# The programs: every one the suites have compiled, and the two tools.
[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
programs=""
for f in bin/rune.rbc bin/runedoc.rbc tests/out/*.rbc tests/out/matrix/rune/*.dir/prog.rbc; do
  [ -f "$f" ] && programs="$programs $f"
done
# shellcheck disable=SC2086
results=$(printf '%s\n' $programs | xargs -n 1 -P "$jobs" sh tests/opt/run-opt-tests.sh --runeopt "$opt" --vm "$vm" --one)
nprog=$(printf '%s\n' "$results" | grep -c '^OK$')
failures=$(printf '%s\n' "$results" | grep -v '^OK$' | grep .)
if [ -n "$failures" ]; then
  printf '%s\n' "$failures"
  fail=$((fail + $(printf '%s\n' "$failures" | wc -l)))
fi
pass=$((pass + nprog))

# same NAME RBC: the program of RBC translated does what it does under runevm
same() {
  name=$1 rbc=$2
  if ! "$opt" "$rbc" -o "$out/$name" > "$out/$name.opt" 2>&1; then
    echo "FAIL opt.run.$name: runeopt failed: $(head -1 "$out/$name.opt")"
    fail=$((fail + 1))
    return
  fi
  "$vm" --count "$rbc" < /dev/null > "$out/$name.vm.stdout" 2> "$out/$name.vm.stderr"
  vcode=$?
  RUNEVM_OPTIONS=--count "$out/$name" < /dev/null > "$out/$name.stdout" 2> "$out/$name.stderr"
  ncode=$?
  if [ "$vcode" != "$ncode" ]; then
    echo "FAIL opt.run.$name: exit status $ncode, runevm's $vcode"
    fail=$((fail + 1))
  elif ! cmp -s "$out/$name.stdout" "$out/$name.vm.stdout"; then
    echo "FAIL opt.run.$name: the output differs from runevm's (diff $out/$name.stdout $out/$name.vm.stdout)"
    fail=$((fail + 1))
  elif ! cmp -s "$out/$name.stderr" "$out/$name.vm.stderr"; then
    echo "FAIL opt.run.$name: standard error or the counts differ (diff $out/$name.stderr $out/$name.vm.stderr)"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

missing=""
for op in $(awk '!/^#/ && NF { print $1 }' vm/opcodes.def); do
  grep -qE "^[[:space:]]*$op([[:space:]]|$)" tests/opt/every-opcode.rasm || missing="$missing $op"
done
if [ -n "$missing" ]; then
  echo "FAIL opt.every-opcode: tests/opt/every-opcode.rasm does not run$missing"
  fail=$((fail + 1))
fi
printf "$(awk -v opdefs=vm/opcodes.def -v primdefs=vm/prims.def -f tests/opt/rbcasm.awk tests/opt/every-opcode.rasm)" > "$out/every-opcode.rbc"
same every-opcode "$out/every-opcode.rbc"
# The primitives runeopt inlines on their edge cases: prims.sml must
# have a PRIM of each, as --disasm shows it.
if "$rune" tests/opt/prims.sml -o "$out/prims.rbc" 2> "$out/prims.cerr"; then
  missing=""
  used=$("$opt" --disasm "$out/prims.rbc" | awk '$2 == "PRIM" { print $3 }' | sort -u | tr '\n' ' ')
  for name in $("$opt" --inlined); do
    idx=$(awk -v name="$name" '!/^#/ && NF { if ($1 == name) print n; n++ }' vm/prims.def)
    case " $used " in *" $idx "*) ;; *) missing="$missing $name" ;; esac
  done
  if [ -n "$missing" ]; then
    echo "FAIL opt.prims: tests/opt/prims.sml does not use$missing, which runeopt inlines"
    fail=$((fail + 1))
  fi
  same prims "$out/prims.rbc"
else
  echo "FAIL opt.run.prims: rune failed: $(head -1 "$out/prims.cerr")"
  fail=$((fail + 1))
fi
for src in examples/hello.sml examples/fib.sml examples/nqueens.sml tests/perf/fib.sml tests/perf/tak.sml; do
  name=$(echo "$src" | tr '/' '_' | sed 's/\.sml$//')
  if "$rune" "$src" -o "$out/$name.rbc" 2> "$out/$name.cerr"; then same "$name" "$out/$name.rbc"
  else echo "FAIL opt.run.$name: rune failed: $(head -1 "$out/$name.cerr")"; fail=$((fail + 1)); fi
done

# Images: a program that saves itself, saved by runevm and carried on
# natively (runeopt --from-image), and the other way round; and an image of
# another program, which a native program refuses with OS.SysErr.
# check NAME WANT GOT: the file GOT holds what the file WANT holds
check() {
  if cmp -s "$2" "$3"; then pass=$((pass + 1))
  else echo "FAIL opt.$1: not what $2 says (diff $2 $3)"; fail=$((fail + 1)); fi
}
img=tests/out/rt.save_first.img
if "$rune" tests/lang/rt.save_first.sml -o "$out/first.rbc" 2> "$out/first.cerr" &&
   "$opt" "$out/first.rbc" -o "$out/first" > "$out/first.opt" 2>&1; then
  rm -f "$img"
  "$vm" "$out/first.rbc" > /dev/null 2>&1
  if "$opt" --from-image "$img" -o "$out/first-image" > "$out/first-image.opt" 2>&1; then
    RUNEVM_OPTIONS="--restore $img" "$out/first-image" > "$out/vm-to-native" 2>&1
    check image.vm-to-native tests/lang/rt.save_first.restore "$out/vm-to-native"
  else echo "FAIL opt.image.from-image: $(head -1 "$out/first-image.opt")"; fail=$((fail + 1)); fi
  rm -f "$img"
  "$out/first" > /dev/null 2>&1
  "$vm" --restore "$img" > "$out/native-to-vm" 2>&1
  check image.native-to-vm tests/lang/rt.save_first.restore "$out/native-to-vm"
  if "$rune" tests/opt/foreign.sml -o "$out/foreign.rbc" 2> "$out/foreign.cerr" &&
     "$opt" "$out/foreign.rbc" -o "$out/foreign" > "$out/foreign.opt" 2>&1; then
    "$out/foreign" > "$out/foreign.out" 2>&1
    printf 'refused: noexec\n' > "$out/foreign.want"
    check image.foreign "$out/foreign.want" "$out/foreign.out"
  else echo "FAIL opt.image.foreign: runeopt or rune failed"; fail=$((fail + 1)); fi
else
  echo "FAIL opt.image: rune or runeopt failed on rt.save_first: $(head -1 "$out/first.cerr" "$out/first.opt")"
  fail=$((fail + 1))
fi

echo "opt: passed $pass, failed $fail ($nprog programs checked and disassembled)"
[ "$fail" = 0 ]
