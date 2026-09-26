#!/bin/sh
# Cycles and instructions of every configuration, on the programs of
# tests/perf and on the compiler compiling itself (docs/plans/jit.md, M1):
#   scripts/perf-cycles.sh [--runs N] [--configs C1,C2,...] [--profile CONFIG] [FILTER]
# The configurations are rune (bin/runevm), new (bin/runevm-new as it
# runs by default: tiering up, since M6), opt (runeopt's native code) and
# mlton (MLton's build); all four unless --configs says otherwise. jit is
# bin/runevm-new --jit=all, every function given to the JIT
# (docs/plans/jit.md, M3), and the same for jit-off (the interpreter
# alone), -baseline and -opt; jit-baseline+c10+w100 is --jit=baseline
# --jit-calls=10 --jit-work=100 (M6, the sweep). Each program is wrapped as `make perf` wraps it
# (tests/basis/run-matrix.sh, wall_program): its body as a function called R
# times, R from the `wall R` line of its .budget, so that a run is long
# enough to measure and the numbers stand beside docs/performance.md's. The
# bootstrap is the compiler compiling its own sources (BOOT_SRCS). Each
# measurement runs N times (5 unless --runs says otherwise) under
# `perf stat -e cycles:u,instructions:u`, and the run with the least cycles
# counts. --profile CONFIG runs the bootstrap once more under `perf record`
# and prints where its time goes by symbol. The table is written to stdout
# as Markdown; the raw numbers are left in tests/out/cycles/.
set -u
runs=5
configs="rune,new,opt,mlton"
profile=""
filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) runs=$2; shift 2 ;;
    --configs) configs=$2; shift 2 ;;
    --profile) profile=$2; shift 2 ;;
    -*) echo "usage: scripts/perf-cycles.sh [--runs N] [--configs C1,C2,...] [--profile CONFIG] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
cd "$(dirname "$0")/.."
perf=${PERF:-perf}
command -v "$perf" > /dev/null 2>&1 || { echo "perf-cycles: perf is not on the PATH" >&2; exit 2; }
mlton=${MLTON:-${RUNE_HOSTS:-$HOME/.local/rune-hosts}/mlton/bin/mlton}
rune=${RUNE:-bin/rune}
out=tests/out/cycles
mkdir -p "$out"

boot_sources() {
  echo build/config.sml
  grep -v -E '^[[:space:]]*(#|$)' sources.txt
  echo src/main/rune-main.sml
}

# wrap NAME R FILE: tests/perf/NAME.sml as the body of a function FILE calls
# R times, its CommandLine shadowed as make perf shadows it.
wrap() {
  {
    echo 'structure CommandLine = struct fun name () = "bench" fun arguments () : string list = [] end'
    echo 'fun runeBody__ () = let'
    cat "tests/perf/$1.sml"
    echo 'in () end'
    echo "fun runeLoop__ 0 = () | runeLoop__ k = (runeBody__ (); runeLoop__ (k - 1))"
    echo "val () = runeLoop__ $2"
  } > "$3"
}

# jit_mode CONFIG: the --jit option of the jit configurations
jit_mode() {
  case "$1" in jit) echo "--jit=all"; return ;; esac
  spec=${1#jit-}
  opts="--jit=${spec%%+*}"
  rest=${spec#"${spec%%+*}"}
  while [ -n "$rest" ]; do
    rest=${rest#+}
    item=${rest%%+*}
    rest=${rest#"$item"}
    case $item in
      c*) opts="$opts --jit-calls=${item#c}" ;;
      w*) opts="$opts --jit-work=${item#w}" ;;
    esac
  done
  echo "$opts"
}

# build CONFIG NAME FILE: what runs FILE (a program) in CONFIG, as a command
# line on stdout; nothing where the configuration cannot be built.
build() {
  case "$1" in
    rune)
      "$rune" "$3" -o "$out/$2.rbc" 2> "$out/$2.rune.err" || return 1
      echo "bin/runevm $out/$2.rbc" ;;
    new)
      "$rune" --target=registers "$3" -o "$out/$2.new.rbc" 2> "$out/$2.new.err" || return 1
      echo "bin/runevm-new $out/$2.new.rbc" ;;
    jit|jit-*)
      "$rune" --target=registers "$3" -o "$out/$2.new.rbc" 2> "$out/$2.new.err" || return 1
      echo "bin/runevm-new $(jit_mode "$1") $out/$2.new.rbc" ;;
    opt)
      "$rune" "$3" -o "$out/$2.rbc" 2> "$out/$2.rune.err" || return 1
      bin/runeopt-mlton "$out/$2.rbc" -o "$out/$2.native" 2> "$out/$2.opt.err" || return 1
      echo "$out/$2.native" ;;
    mlton)
      [ -x "$mlton" ] || return 1
      "$mlton" -output "$out/$2.mlton" "$3" > "$out/$2.mlton.err" 2>&1 || return 1
      echo "$out/$2.mlton" ;;
    *) return 1 ;;
  esac
}

# the bootstrap in CONFIG: its command line, or nothing
bootstrap() {
  srcs=$(boot_sources | tr '\n' ' ')
  case "$1" in
    rune) echo "bin/runevm --heap-size 67108864 bin/rune.rbc --lib lib -o $out/boot.$1.rbc $srcs" ;;
    new) [ -f bin/rune.new.rbc ] || return 1
         echo "bin/runevm-new --heap-size 67108864 bin/rune.new.rbc --lib lib -o $out/boot.$1.rbc $srcs" ;;
    jit|jit-*) [ -f bin/rune.new.rbc ] || return 1
         echo "bin/runevm-new $(jit_mode "$1") --heap-size 67108864 bin/rune.new.rbc --lib lib -o $out/boot.$1.rbc $srcs" ;;
    opt) bin/runeopt-mlton --options "--heap-size 67108864" bin/rune.rbc -o "$out/rune.native" 2> "$out/rune.native.err" || return 1
         echo "$out/rune.native --lib lib -o $out/boot.$1.rbc $srcs" ;;
    mlton) [ -x bin/rune-mlton ] || return 1
           echo "bin/rune-mlton -o $out/boot.$1.rbc $srcs" ;;
    *) return 1 ;;
  esac
}

# measure LABEL CMD...: the least cycles of $runs runs, and that run's
# instructions, as "cycles instructions"; the stdout of the last run is
# kept in $out/LABEL.stdout for the caller to check.
measure() {
  label=$1
  shift
  best=""
  i=0
  while [ $i -lt "$runs" ]; do
    i=$((i + 1))
    "$perf" stat -x, -e cycles:u,instructions:u -o "$out/$label.perf" -- "$@" > "$out/$label.stdout" 2> "$out/$label.stderr" || return 1
    c=$(sed -n 's/^\([0-9]*\),[^,]*,cycles:u,.*/\1/p' "$out/$label.perf")
    n=$(sed -n 's/^\([0-9]*\),[^,]*,instructions:u,.*/\1/p' "$out/$label.perf")
    [ -n "$c" ] && [ -n "$n" ] || return 1
    if [ -z "$best" ] || [ "$c" -lt "${best%% *}" ]; then best="$c $n"; fi
  done
  echo "$best"
}

# human N: N in millions, or in thousands of millions from 1G, one decimal
human() {
  awk "BEGIN { if ($1 >= 1000000000) printf \"%.1fG\", $1 / 1000000000; else printf \"%.1fM\", $1 / 1000000 }"
}

cfgs=$(echo "$configs" | tr ',' ' ')
programs=""
for f in tests/perf/*.sml; do
  name=$(basename "$f" .sml)
  [ -f "tests/perf/$name.expected" ] || continue
  case "$name" in *"$filter"*) programs="$programs $name" ;; esac
done
case "bootstrap" in *"$filter"*) programs="$programs bootstrap" ;; esac

echo "| Program | $(echo "$cfgs" | sed 's/ / | /g') |"
echo "|---|$(for c in $cfgs; do printf -- '---:|'; done)"
for name in $programs; do
  line="| $name |"
  base=""
  for c in $cfgs; do
    if [ "$name" = bootstrap ]; then
      cmd=$(bootstrap "$c") || { line="$line n/a |"; continue; }
    else
      reps=$(sed -n 's/^wall //p' "tests/perf/$name.budget")
      wrap "$name" "${reps:-1}" "$out/$name.wrapped.sml"
      cmd=$(build "$c" "$name" "$out/$name.wrapped.sml") || { line="$line n/a |"; continue; }
    fi
    # shellcheck disable=SC2086
    got=$(measure "$name.$c" $cmd) || { line="$line FAIL |"; continue; }
    if [ "$name" != bootstrap ] && ! grep -q -x -F -f "tests/perf/$name.expected" "$out/$name.$c.stdout"; then
      line="$line WRONG |"; continue
    fi
    cycles=${got%% *}
    instrs=${got#* }
    [ -z "$base" ] && base=$cycles
    ratio=$(awk "BEGIN { printf \"%.2f\", $cycles / $base }")
    line="$line $(human "$cycles") cycles, $(human "$instrs") instr. ($ratio) |"
    echo "$name $c $cycles $instrs" >> "$out/numbers.txt"
  done
  echo "$line"
done

if [ -n "$profile" ]; then
  cmd=$(bootstrap "$profile") || { echo "perf-cycles: cannot build the bootstrap in $profile" >&2; exit 1; }
  # shellcheck disable=SC2086
  "$perf" record -e cycles:u -o "$out/boot.$profile.data" -- $cmd > /dev/null 2> "$out/boot.$profile.record.err" || exit 1
  echo
  echo "The bootstrap in $profile, by symbol (perf record):"
  echo
  "$perf" report -i "$out/boot.$profile.data" --stdio --sort symbol 2> /dev/null | grep -v '^#' | grep -v '^$' | head -25
fi
