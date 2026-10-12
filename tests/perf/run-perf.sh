#!/bin/sh
# Performance budgets: deterministic counts instead of seconds.
#   tests/perf/run-perf.sh [--stack] [--update] [FILTER]
# `runevm --count` reports the instructions a run executes and the bytes and
# objects it allocates. These depend on the program, its input and the
# compiler, not on the machine or its load, so a budget on them is a test
# that cannot flake. What is measured is Rune as it is shipped: each program
# compiled by bin/rune to the register bytecode and run by bin/runevm, the
# compiler and runedoc as bin/rune.rbc and bin/runedoc.rbc on bin/runevm.
# Every tests/perf/NAME.budget is one measurement:
#
#   args A...          command-line arguments of the program (optional)
#   compile ARG...     measure the compiler (bin/rune.rbc) compiling these
#                      files, with these options, instead of running
#                      tests/perf/NAME.sml; @boot stands for the compiler's
#                      own sources, @gen for the program of `generate`
#   generate KIND N... the program tests/perf/gen.py KIND N... writes, for
#                      `compile` (docs/plans/performance.md, M1: programs that
#                      scale one construct of the module language)
#   runedoc ARG...     measure the documentation generator (bin/runedoc.rbc)
#                      with these arguments instead; the shell expands a *
#   scale N EXPONENT   also run with the arguments N and 4N: the instructions
#                      may grow with at most N^(EXPONENT + 0.15)
#   wall R             `make perf` runs the program R times per measurement
#                      (tests/basis/run-matrix.sh --perf); ignored here
#   noxc1 REASON       `make perf` does not run it on Rune's library compiled
#                      by a host; ignored here
#   nostack REASON     --stack does not measure it
#   instructions N     the budgets: the measured values plus 10 %
#   bytes N
#   objects N
#
# A program prints a checksum, which must equal tests/perf/NAME.expected (the
# output of the program on MLton, so an independent result). A measurement
# above its budget fails. --update rewrites the three budget lines from the
# measurements: do that for a deliberate change, and say why in the commit.
# Override the compiler and the VM with RUNE= and RUNEVM=.
#
# --stack measures the stack bytecode instead: each program compiled with
# --target=stack and run by bin/runevm-stack, the compiler and runedoc as
# bin/rune.stack.rbc and bin/runedoc.stack.rbc (what runeopt translates),
# and the budgets are tests/perf/stack/NAME.budget, beside the measurement
# that tests/perf/NAME.budget describes. (--new, which named the register
# VM before it was the default, is the default.)
set -u
update=0
stack=0
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --update) update=1; shift ;;
    --stack) stack=1; shift ;;
    --new) stack=0; shift ;;
    -*) echo "usage: tests/perf/run-perf.sh [--stack] [--update] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
# a compiler or VM given by a path relative to here is the one meant
for v in RUNE RUNEVM; do
  eval "p=\${$v:-}"
  case "$p" in ''|/*) ;; */*) [ -e "$p" ] && eval "$v=\$(pwd)/\$p" ;; esac
done
cd "$(dirname "$0")/../.."
rune=${RUNE:-bin/rune}
vm=${RUNEVM:-bin/runevm}
flags=--target=registers
compiler=bin/rune.rbc
runedocrbc=bin/runedoc.rbc
out=tests/out/perf
if [ $stack = 1 ]; then
  vm=${RUNEVM:-bin/runevm-stack}
  flags=--target=stack
  compiler=bin/rune.stack.rbc
  runedocrbc=bin/runedoc.stack.rbc
  out=tests/out/perf-stack
  mkdir -p tests/perf/stack
fi
mkdir -p "$out"
status=0

# counters FILE: "instructions bytes objects" from the --count line of a stderr.
counters() {
  sed -n 's/^runevm: count: \([0-9]*\) instructions, \([0-9]*\) bytes, \([0-9]*\) objects$/\1 \2 \3/p' "$1" | tail -1
}

boot_sources() {
  echo build/config.sml
  sh scripts/build-files.sh rune.build
  echo src/main/rune-main.sml
}

# measure NAME ARGS...: run the measurement of NAME; leaves NAME.stdout/.stderr.
# A run that did not do its work fails, whatever it counted: the VM must exit
# 0, a compile write its bytecode (or type-check its input with
# --typecheck-only), runedoc print, and a generated program be there.
measure() {
  name=$1
  shift
  compile=$(sed -n 's/^compile //p' "tests/perf/$name.budget")
  runedoc=$(sed -n 's/^runedoc //p' "tests/perf/$name.budget")
  generate=$(sed -n 's/^generate //p' "tests/perf/$name.budget")
  if [ -n "$generate" ]; then
    # shellcheck disable=SC2086
    python3 tests/perf/gen.py $generate > "$out/$name.gen.sml" && [ -s "$out/$name.gen.sml" ] || return 1
  fi
  rm -f "$out/$name.stdout" "$out/$name.out.rbc"
  if [ -n "$runedoc" ]; then
    # shellcheck disable=SC2086
    "$vm" --count --heap-size 67108864 "$runedocrbc" --lib lib $runedoc \
      > "$out/$name.stdout" 2> "$out/$name.stderr" && [ -s "$out/$name.stdout" ]
  elif [ -n "$compile" ]; then
    files=""
    for f in $compile; do
      case "$f" in
        @boot) files="$files $(boot_sources | tr '\n' ' ')" ;;
        @gen) files="$files $out/$name.gen.sml" ;;
        *) files="$files $f" ;;
      esac
    done
    # shellcheck disable=SC2086
    "$vm" --count --heap-size 67108864 "$compiler" --lib lib $flags -o "$out/$name.out.rbc" $files \
      > "$out/$name.stdout" 2> "$out/$name.stderr" || return 1
    case " $compile " in *" --typecheck-only "*) ;; *) [ -s "$out/$name.out.rbc" ] ;; esac
  else
    # shellcheck disable=SC2086
    "$rune" $flags "tests/perf/$name.sml" -o "$out/$name.rbc" 2> "$out/$name.stderr" || return 1
    "$vm" --count "$out/$name.rbc" "$@" > "$out/$name.stdout" 2> "$out/$name.stderr"
  fi
}

for spec in tests/perf/*.budget; do
  name=$(basename "$spec" .budget)
  case "$name" in *"$filter"*) ;; *) continue ;; esac
  [ $stack = 1 ] && grep -q '^nostack ' "$spec" && continue
  # the numbers: bin/runevm's beside the description, runevm-stack's apart
  budget=$spec
  if [ $stack = 1 ]; then
    budget=tests/perf/stack/$name.budget
    [ -f "$budget" ] || : > "$budget"
  fi
  args=$(sed -n 's/^args //p' "$spec")
  # shellcheck disable=SC2086
  if ! measure "$name" $args; then
    echo "FAIL $name: $(head -1 "$out/$name.stderr")"
    status=1
    continue
  fi
  got=$(counters "$out/$name.stderr")
  if [ -z "$got" ]; then
    echo "FAIL $name: no counters: $(head -1 "$out/$name.stderr")"
    status=1
    continue
  fi
  if [ -f "tests/perf/$name.expected" ] && ! cmp -s "$out/$name.stdout" "tests/perf/$name.expected"; then
    echo "FAIL $name: printed $(head -1 "$out/$name.stdout"), expected $(head -1 "tests/perf/$name.expected")"
    status=1
    continue
  fi
  set -- $got
  if [ $update = 1 ]; then
    { grep -v -E '^(instructions|bytes|objects) ' "$budget"
      echo "instructions $(($1 + $1 / 10))"
      echo "bytes $(($2 + $2 / 10))"
      echo "objects $(($3 + $3 / 10))"
    } > "$budget.tmp" && mv "$budget.tmp" "$budget"
  fi
  line="$name:"
  ok=1
  for pair in "instructions $1" "bytes $2" "objects $3"; do
    key=${pair% *}
    value=${pair#* }
    limit=$(sed -n "s/^$key //p" "$budget")
    if [ -z "$limit" ]; then
      echo "FAIL $name: no $key budget (run tests/perf/run-perf.sh$([ $stack = 1 ] && echo ' --stack') --update $name)"
      ok=0
    elif [ "$value" -gt "$limit" ]; then
      echo "FAIL $name: $value $key, budget $limit"
      ok=0
    fi
    line="$line $value $key"
  done
  scale=$(sed -n 's/^scale //p' "$spec")
  if [ -n "$scale" ]; then
    n=${scale% *}
    exponent=${scale#* }
    measure "$name" "$n" && i1=$(counters "$out/$name.stderr" | cut -d ' ' -f 1)
    measure "$name" $((n * 4)) && i4=$(counters "$out/$name.stderr" | cut -d ' ' -f 1)
    grown=$(awk -v a="${i1:-0}" -v b="${i4:-0}" 'BEGIN { if (a > 0 && b > 0) printf "%.2f", log(b / a) / log(4); else print "?" }')
    if [ "$grown" = "?" ] || awk -v g="$grown" -v e="$exponent" 'BEGIN { exit !(g > e + 0.15) }'; then
      echo "FAIL $name: instructions grow with n^$grown from n = $n to $((n * 4)), expected at most n^$exponent"
      ok=0
    fi
    line="$line, n^$grown"
  fi
  [ $ok = 1 ] && echo "ok   $line" || status=1
done
[ $status = 0 ] && echo "perf-check: within budget"
exit $status
