#!/bin/sh
# What the VM refuses before it runs anything (part of make test):
#   tests/vm/run-vm-tests.sh [--vm BIN] [--out DIR]
# Each case writes a bytecode file by hand, or gives runevm an option, with a
# length or a size chosen to overflow what is computed from it, and expects
# runevm to say what is wrong and exit with status 2 -- not to crash, and not
# to run. The lengths in a bytecode file are 32 bits wide, so they can wrap a
# size only where size_t is 32 bits too: the cases matter most for the 32-bit
# Windows VM (make test-windows), and they hold for every VM.
#
# The VM is given the name of the file relative to the directory it runs in,
# which is what a Windows VM started from WSL can open.
set -u
vm=bin/runevm
out=tests/out/vm
while [ $# -gt 0 ]; do
  case $1 in
    --vm) vm=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    *) echo "usage: $0 [--vm BIN] [--out DIR]" >&2; exit 2 ;;
  esac
done
cd "$(dirname "$0")/../.."
case $vm in /*) ;; *) vm=$(pwd)/$vm ;; esac
mkdir -p "$out"
cd "$out" || exit 2

pass=0
fail=0
# expect NAME MESSAGE ARGS...: runevm ARGS exits with 2 and its standard
# error contains MESSAGE
expect() {
  name=$1 message=$2
  shift 2
  "$vm" "$@" > "$name.stdout" 2> "$name.stderr" < /dev/null
  code=$?
  if [ "$code" = 2 ] && grep -qF -- "$message" "$name.stderr"; then
    pass=$((pass + 1))
  else
    echo "FAIL vm.$name: exit code $code, expected 2 and \"$message\": $(head -1 "$name.stderr")"
    fail=$((fail + 1))
  fi
}

# the header: "RUNE", version 2; numbers are 32 bits, little-endian
header='RUNE\002\000\000\000'
one='\001\000\000\000'
zero='\000\000\000\000'
huge='\377\377\377\377'

printf '' > empty.rbc
expect empty "not a Rune bytecode file" empty.rbc

printf 'RUNE\003\000\000\000' > version.rbc
expect version "unsupported bytecode version" version.rbc

# version 1: the layout before the line table (docs/bytecode.md)
printf 'RUNE\001\000\000\000' > version1.rbc
expect version1 "unsupported bytecode version" version1.rbc

# one constant, a string of 0xFFFFFFF0 bytes
printf "$header$one\\003\\360\\377\\377\\377" > string.rbc
expect string "bad string constant" string.rbc

# one constant, a real written in 0xFFFFFFFF characters
printf "$header$one\\002$huge" > real.rbc
expect real "bad real constant" real.rbc

# no constants, no globals, one function whose name is 0xFFFFFFFF bytes
printf "$header$zero$zero$one$zero$one$huge" > name.rbc
expect name "bad function name" name.rbc

# one function with an empty name, then 0xFFFFFFFF bytes of code
printf "$header$zero$zero$one$zero$one$zero$huge" > code.rbc
expect code "truncated code" code.rbc

# a size that fits no size_t (2^64), and one that is not a number
expect heap-size "usage:" --heap-size 18446744073709551616 empty.rbc
expect heap-size-text "usage:" --heap-size 64M empty.rbc
expect gc-stress "usage:" --gc-stress 18446744073709551616 empty.rbc
# a share of the heap that is none, and one of more than all of it
expect heap-fill-zero "usage:" --heap-fill 0 empty.rbc
expect heap-fill-over "usage:" --heap-fill 101 empty.rbc

# The debug section (docs/bytecode.md). A whole program, then the
# line table broken in each of the ways the loader has to refuse. `prog` is
# one function `f` whose only instruction is HALT, and `dbg` its files.
prog="$header$zero$zero$one$zero$one\\001\\000\\000\\000f$one\\000"
onefile="$one\\001\\000\\000\\000a"

# a file table longer than the file
printf "$prog$huge" > files.rbc
expect debug-files "bad file table" files.rbc

# one file whose name runs past the end
printf "$prog$one$huge" > filename.rbc
expect debug-filename "bad file name" filename.rbc

# a table of one entry, but no bytes for it
printf "$prog$onefile$one$zero" > lines.rbc
expect debug-lines "bad line table" lines.rbc

# an entry whose pc is past the code: dpc 9, file 0, line 1, column 1
printf "$prog$onefile$one\\004\\000\\000\\000\\011\\000\\002\\002" > linepc.rbc
expect debug-line-pc "line table out of range" linepc.rbc

# an entry naming file 1, where there is one file: dpc 0, dfile 1, line 1, col 1
printf "$prog$onefile$one\\004\\000\\000\\000\\000\\002\\002\\002" > linefile.rbc
expect debug-line-file "line table out of range" linefile.rbc

# an entry at line 0, which no file has: dpc 0, dfile 0, dline 0, dcol 1
printf "$prog$onefile$one\\004\\000\\000\\000\\000\\000\\000\\002" > lineno.rbc
expect debug-line-zero "line table out of range" lineno.rbc

# bytes left over after the entries the count promised
printf "$prog$onefile$one\\005\\000\\000\\000\\000\\000\\002\\002\\000" > linetail.rbc
expect debug-line-tail "bad line table" linetail.rbc

# A fatal error names the function it happened in, which is the name the
# compiler put in the file (docs/bytecode.md). One function called
# `queens`, one instruction, SELF (opcode 8) where there is no closure.
printf "$header$zero$zero$one$zero$one\\006\\000\\000\\000queens$one\\010$zero$zero$zero" > named.rbc
expect named-function "fatal error at pc 1 in queens" named.rbc

# the child of a fork by a second VM (vm/image.c) with no image to read:
# standard input is empty, and x names no descriptor or handle
expect resume "no image to resume from" --resume 0
expect resume-token "no image to resume from" --resume x

echo "vm: passed $pass, failed $fail"
[ "$fail" = 0 ]
