#!/bin/sh
# What must determine a flexible record's labels, in each mode of
# --flex-records (docs/language.md): each program of this directory
# compiled whole and in units, and used at the REPL, in every mode, and
# accepted -- printing what it prints -- or refused with "unresolved
# flexible record" as the table below says. The table is what the
# implementations each mode follows did with the same programs
# (2026-10-09): binding is SML/NJ's and Hamlet's, declaration MLKit's,
# topdec-monomorphic Moscow ML's, topdec Poly/ML's and MLton's, program
# Rune's before the option.
#   tests/flexrec/run.sh [--rune BIN]
set -u
cd "$(dirname "$0")/../.."
rune=bin/rune
[ "${1:-}" = --rune ] && rune=$2
repl=$(dirname "$rune")/rune-repl
vm=$(dirname "$rune")/runevm
out=tests/out/flexrec
mkdir -p "$out"
pass=0
fail=0

# mode: same_let next_dec in_structure two_types after_semicolon -- 1
# accepted, 0 refused as an unresolved flexible record, 2 refused as a type
# mismatch (a record not generalised, met at two types)
table="binding:0 0 0 0 0
declaration:1 0 0 0 0
topdec-monomorphic:1 1 1 2 0
topdec:1 1 1 1 0
program:1 1 1 1 1"
programs="same_let next_dec in_structure two_types after_semicolon"
expected_out() {
  case $1 in two_types) echo "1two" ;; *) echo 1 ;; esac
}

check() {   # check MODE PROGRAM WANT HOW
  mode=$1 p=$2 want=$3 how=$4
  case $how in
    whole) "$rune" --flex-records="$mode" "tests/flexrec/$p.sml" -o "$out/$p.$mode.rbc" > "$out/$p.$mode.$how.err" 2>&1 ;;
    units) "$rune" --flex-records="$mode" --units --no-cache "tests/flexrec/$p.sml" -o "$out/$p.$mode.rbc" > "$out/$p.$mode.$how.err" 2>&1 ;;
  esac
  got=$?
  if [ "$want" = 1 ]; then
    if [ $got != 0 ]; then
      echo "FAIL flexrec.$mode.$p ($how): refused, wanted accepted ($out/$p.$mode.$how.err)"; fail=$((fail + 1)); return
    fi
    if [ "$("$vm" "$out/$p.$mode.rbc")" != "$(expected_out "$p")" ]; then
      echo "FAIL flexrec.$mode.$p ($how): printed other than $(expected_out "$p")"; fail=$((fail + 1)); return
    fi
  else
    case $want in 0) reason='unresolved flexible record' ;; *) reason='type mismatch' ;; esac
    if [ $got = 0 ] || ! grep -q "$reason" "$out/$p.$mode.$how.err"; then
      echo "FAIL flexrec.$mode.$p ($how): accepted, or refused for another reason ($out/$p.$mode.$how.err)"
      fail=$((fail + 1)); return
    fi
  fi
  pass=$((pass + 1))
}

echo "$table" | while IFS=: read -r mode wants; do
  pass=0
  fail=0
  set -- $wants
  for p in $programs; do
    check "$mode" "$p" "$1" whole
    check "$mode" "$p" "$1" units
    shift
  done
  echo "$pass $fail" > "$out/counts.$mode"
done
total_pass=0
total_fail=0
for mode in binding declaration topdec-monomorphic topdec program; do
  set -- $(cat "$out/counts.$mode")
  total_pass=$((total_pass + $1)); total_fail=$((total_fail + $2))
done

# The REPL, in the default mode: a file used whole is a top-level
# declaration where it has no `;`, and so next_dec.sml and two_types.sml are
# accepted as Poly/ML accepts them; after_semicolon.sml is refused at its
# first `;`
for p in next_dec two_types after_semicolon; do
  printf 'use "tests/flexrec/%s.sml";\n' "$p" | RUNE_CACHE= "$repl" > "$out/$p.repl" 2>&1
  case $p in
    after_semicolon) grep -q 'unresolved flexible record' "$out/$p.repl" ;;
    *) grep -q "$(expected_out "$p")\$" "$out/$p.repl" && ! grep -q 'error' "$out/$p.repl" ;;
  esac
  if [ $? = 0 ]; then total_pass=$((total_pass + 1))
  else echo "FAIL flexrec.repl.$p ($out/$p.repl)"; total_fail=$((total_fail + 1)); fi
done

echo "flexrec: passed $total_pass, failed $total_fail"
[ $total_fail = 0 ]
