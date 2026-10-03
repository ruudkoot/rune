#!/bin/sh
# Cycles and instructions of every configuration, on the programs of
# tests/perf and on the compiler compiling itself (docs/plans/jit.md, M1):
#   scripts/perf-cycles.sh [--runs N] [--configs C1,C2,...] [--events LIST] [--vm-opts OPTS]
#                          [--vm BIN] [--gc] [--profile CONFIG[:PROGRAM]]
#                          [--mlton-bench DIR NFILE] [--sweep] [FILTER]
# The configurations are rune (bin/runevm-stack), new (bin/runevm as it
# runs by default: tiering up, since M6), opt (runeopt's native code) and
# mlton (MLton's build); all four unless --configs says otherwise. jit is
# bin/runevm --jit=all, every function given to the JIT
# (docs/plans/jit.md, M3), and the same for jit-off (the interpreter
# alone), -baseline and -opt; jit-baseline+c10+w100 is --jit=baseline
# --jit-calls=10 --jit-work=100 (M6, the sweep), and +t2 adds --jit-tier=2
# (M9: jit-all+t2 is every function at tier 2). Each program is wrapped as `make perf` wraps it
# (tests/basis/run-matrix.sh, wall_program): its body as a function called R
# times, R from the `wall R` line of its .budget, so that a run is long
# enough to measure and the numbers stand beside docs/performance.md's. The
# bootstrap is the compiler compiling its own sources (BOOT_SRCS), and
# compile-sigs and runedoc-page are the compiler and runedoc on the inputs
# their .budget files name, run as the bootstrap is. Each measurement runs
# N times (5 unless --runs says otherwise) under `perf stat -e
# cycles:u,instructions:u` (--events LIST counts LIST instead; cycles:u and
# instructions:u must be in it, and cycles:uD pins them where LIST would
# multiplex), and the run with the least cycles counts, every counter from
# that run. --vm-opts OPTS gives every VM OPTS after the script's own
# options (a native program takes them from RUNEVM_OPTIONS), --vm BIN runs
# the register bytecode on BIN instead of bin/runevm (a VM of another
# layout: docs/plans/heap-layout.md, M4), and --gc adds
# --stats and prints a second table of what the collector did: collections,
# bytes copied, its processor time and the semispace at exit.
# --profile CONFIG[:PROGRAM] runs the bootstrap (or PROGRAM) once more under
# `perf record` -- walking the stack where the binary keeps frame
# pointers -- and prints where its time goes by symbol. --mlton-bench DIR
# NFILE measures MLton's benchmarks instead of tests/perf: DIR/NAME.sml
# followed by `val () = Main.doit N` for every line `NAME N` of NFILE, exit
# status 0 the check. --sweep runs each program at heap sizes that are
# multiples of its largest live size (DaCapo's method): a run at --heap-fill
# 99 from a 4 MiB heap finds L, the most a collection kept, then --heap-fill
# 100 --heap-size k*L for k = 1.25, 1.5, 2, 3, 4, 6, 8 and a 2 GiB heap,
# with --gc's statistics and task-clock and page faults beside the cycles;
# a native program takes each size from RUNEVM_OPTIONS. The table is
# written to stdout as Markdown; the raw numbers are left in
# tests/out/cycles/ (numbers.txt, and sweep.txt for --sweep).
set -u
runs=5
configs="rune,new,opt,mlton"
profile=""
events="cycles:u,instructions:u"
vmopts=""
regvm=bin/runevm
gc=0
bench_dir=""
bench_file=""
filter=""
sweep=0
usage="usage: scripts/perf-cycles.sh [--runs N] [--configs C1,C2,...] [--events LIST] [--vm-opts OPTS] [--vm BIN] [--gc] [--profile CONFIG[:PROGRAM]] [--mlton-bench DIR NFILE] [--sweep] [FILTER]"
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) runs=$2; shift 2 ;;
    --configs) configs=$2; shift 2 ;;
    --profile) profile=$2; shift 2 ;;
    --events) events=$2; shift 2 ;;
    --vm-opts) vmopts="$vmopts $2"; shift 2 ;;
    --vm) regvm=$2; shift 2 ;;
    --gc) gc=1; shift ;;
    --sweep) sweep=1; gc=1; events="cycles:uD,instructions:uD,task-clock,page-faults"; shift ;;
    --mlton-bench) [ $# -ge 3 ] || { echo "$usage" >&2; exit 2; }; bench_dir=$2; bench_file=$3; shift 3 ;;
    -*) echo "$usage" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done
[ $gc = 1 ] && vmopts="$vmopts --stats"
# a native program's options (runtime/native/native.c): after those it was made with
export RUNEVM_OPTIONS="$vmopts"
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

# vm_command CMD: CMD with --vm-opts before the program a VM runs, after
# the script's own options, so that they override; a native program has
# them from RUNEVM_OPTIONS and MLton's build none.
vm_command() {
  case "$1" in
    bin/runevm*) echo "$1" | sed "s| \([^ ]*\.rbc\)| $vmopts \1|" ;;
    *) echo "$1" ;;
  esac
}

# bench_wrap DIR NAME N FILE: DIR/NAME.sml, one of MLton's benchmarks, run
# as MLton's harness runs it: `val () = Main.doit N` after it (--mlton-bench)
bench_wrap() {
  { cat "$1/$2.sml"; echo "val () = Main.doit $3"; } > "$4"
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
      t*) opts="$opts --jit-tier=${item#t}" ;;
    esac
  done
  echo "$opts"
}

# build CONFIG NAME FILE: what runs FILE (a program) in CONFIG, as a command
# line on stdout; nothing where the configuration cannot be built.
build() {
  case "$1" in
    rune)
      "$rune" --target=stack "$3" -o "$out/$2.rbc" 2> "$out/$2.rune.err" || return 1
      echo "bin/runevm-stack $out/$2.rbc" ;;
    new)
      "$rune" --target=registers "$3" -o "$out/$2.new.rbc" 2> "$out/$2.new.err" || return 1
      echo "$regvm $out/$2.new.rbc" ;;
    jit|jit-*)
      "$rune" --target=registers "$3" -o "$out/$2.new.rbc" 2> "$out/$2.new.err" || return 1
      echo "$regvm $(jit_mode "$1") $out/$2.new.rbc" ;;
    opt)
      "$rune" --target=stack "$3" -o "$out/$2.rbc" 2> "$out/$2.rune.err" || return 1
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
    rune) echo "bin/runevm-stack --heap-size 67108864 bin/rune.stack.rbc --lib lib --target=stack -o $out/boot.$1.rbc $srcs" ;;
    new) [ -f bin/rune.rbc ] || return 1
         echo "$regvm --heap-size 67108864 bin/rune.rbc --lib lib -o $out/boot.$1.rbc $srcs" ;;
    jit|jit-*) [ -f bin/rune.rbc ] || return 1
         echo "$regvm $(jit_mode "$1") --heap-size 67108864 bin/rune.rbc --lib lib -o $out/boot.$1.rbc $srcs" ;;
    opt) bin/runeopt-mlton --options "--heap-size 67108864" bin/rune.stack.rbc -o "$out/rune.native" 2> "$out/rune.native.err" || return 1
         echo "$out/rune.native --lib lib --target=stack -o $out/boot.$1.rbc $srcs" ;;
    mlton) [ -x bin/rune-mlton ] || return 1
           echo "bin/rune-mlton --target=stack -o $out/boot.$1.rbc $srcs" ;;
    *) return 1 ;;
  esac
}

# measure LABEL CMD...: the least cycles of $runs runs, and that run's
# instructions, as "cycles instructions"; the stdout of the last run is
# kept in $out/LABEL.stdout for the caller to check, and the counters and
# stderr of the run that counts in $out/LABEL.best.perf and .best.stderr.
measure() {
  label=$1
  shift
  best=""
  i=0
  while [ $i -lt "$runs" ]; do
    i=$((i + 1))
    "$perf" stat -x, -e "$events" -o "$out/$label.perf" -- "$@" > "$out/$label.stdout" 2> "$out/$label.stderr" || return 1
    c=$(sed -n 's/^\([0-9]*\),[^,]*,cycles:uD\{0,1\},.*/\1/p' "$out/$label.perf")
    n=$(sed -n 's/^\([0-9]*\),[^,]*,instructions:uD\{0,1\},.*/\1/p' "$out/$label.perf")
    [ -n "$c" ] && [ -n "$n" ] || return 1
    if [ -z "$best" ] || [ "$c" -lt "${best%% *}" ]; then
      best="$c $n"
      cp "$out/$label.perf" "$out/$label.best.perf"
      cp "$out/$label.stderr" "$out/$label.best.stderr"
    fi
  done
  echo "$best"
}

# counters LABEL: every event of the run that counts, as "event=value ..."
counters() {
  sed -n 's/^\([0-9]*\),[^,]*,\([^,]*\),.*/\2=\1/p' "$out/$1.best.perf" | tr '\n' ' '
}

# gc_stats LABEL: the --stats line of the run that counts (--gc), as
# "collections copied gc-us semispace"; nothing where there is none
gc_stats() {
  sed -n 's/^runevm: \([0-9]*\) collections, [0-9]* bytes allocated, semispace \([0-9]*\) bytes, [0-9]* live, copied \([0-9]*\), max live [0-9]*, gc \([0-9]*\) us$/\1 \3 \4 \2/p' "$out/$1.best.stderr" | tail -1
}

# human N: N in millions, or in thousands of millions from 1G, one decimal
human() {
  awk "BEGIN { if ($1 >= 1000000000) printf \"%.1fG\", $1 / 1000000000; else printf \"%.1fM\", $1 / 1000000 }"
}

# compile_program CONFIG NAME: the measurement tests/perf/NAME.budget
# describes by a `compile FILES` or `runedoc ARGS` line (tests/perf/
# run-perf.sh), in CONFIG: the compiler or runedoc on that input, run as
# bootstrap() runs the compiler, as a command line; nothing where the
# configuration cannot be built.
compile_program() {
  spec=tests/perf/$2.budget
  [ -f "$spec" ] || return 1
  files=$(sed -n 's/^compile //p' "$spec")
  args=$(sed -n 's/^runedoc //p' "$spec")
  target=""
  if [ -n "$args" ]; then
    prog=runedoc
    args="--lib lib $args"
  elif [ -n "$files" ]; then
    prog=rune
    target=" --target=stack"   # what the stack compiler and its translation are measured making (run-perf.sh)
    args="--lib lib -o $out/$2.$1.rbc"
    for f in $files; do
      if [ "$f" = @boot ]; then args="$args $(boot_sources | tr '\n' ' ')"; else args="$args $f"; fi
    done
  else
    return 1
  fi
  case "$1" in
    rune) [ -f "bin/$prog.stack.rbc" ] || return 1
          echo "bin/runevm-stack --heap-size 67108864 bin/$prog.stack.rbc$target $args" ;;
    new) [ -f "bin/$prog.rbc" ] || return 1
         echo "$regvm --heap-size 67108864 bin/$prog.rbc $args" ;;
    jit|jit-*) [ -f "bin/$prog.rbc" ] || return 1
         echo "$regvm $(jit_mode "$1") --heap-size 67108864 bin/$prog.rbc $args" ;;
    opt) [ -f "bin/$prog.stack.rbc" ] || return 1
         bin/runeopt-mlton --options "--heap-size 67108864" "bin/$prog.stack.rbc" -o "$out/$prog.native" 2> "$out/$prog.native.err" || return 1
         echo "$out/$prog.native$target $args" ;;
    mlton) [ -x "bin/$prog-mlton" ] || return 1
           echo "bin/$prog-mlton$target $args" ;;
    *) return 1 ;;
  esac
}

# command CONFIG NAME: what runs NAME in CONFIG -- a program of tests/perf
# wrapped, one of MLton's benchmarks (--mlton-bench), or the compiler or
# runedoc on the input of a .budget -- with --vm-opts; nothing where it
# cannot be built
command_of() {
  if [ "$2" = bootstrap ]; then
    cmd=$(bootstrap "$1") || return 1
  elif [ -n "$bench_dir" ]; then
    n=$(awk -v p="$2" '$1 == p { print $2 }' "$bench_file")
    bench_wrap "$bench_dir" "$2" "${n:-1}" "$out/$2.wrapped.sml"
    cmd=$(build "$1" "$2" "$out/$2.wrapped.sml") || return 1
  elif [ -f "tests/perf/$2.expected" ]; then
    reps=$(sed -n 's/^wall //p' "tests/perf/$2.budget")
    wrap "$2" "${reps:-1}" "$out/$2.wrapped.sml"
    cmd=$(build "$1" "$2" "$out/$2.wrapped.sml") || return 1
  else
    cmd=$(compile_program "$1" "$2") || return 1
  fi
  vm_command "$cmd"
}

# frame_pointers BIN: whether BIN keeps frame pointers, by the prologue of
# copy_obj, of the runtime every configuration but mlton links: then perf
# record can walk its stack (--profile)
frame_pointers() {
  objdump -d --disassemble=copy_obj "$1" 2> /dev/null | grep -q 'mov  *%rsp,%rbp'
}

cfgs=$(echo "$configs" | tr ',' ' ')
programs=""
if [ -n "$bench_dir" ]; then
  for name in $(grep -v -E '^[[:space:]]*(#|$)' "$bench_file" | awk '{ print $1 }'); do
    case "$name" in *"$filter"*) programs="$programs $name" ;; esac
  done
else
  for f in tests/perf/*.sml; do
    name=$(basename "$f" .sml)
    [ -f "tests/perf/$name.expected" ] || continue
    case "$name" in *"$filter"*) programs="$programs $name" ;; esac
  done
  for name in compile-sigs runedoc-page bootstrap; do
    case "$name" in *"$filter"*) programs="$programs $name" ;; esac
  done
fi

echo "| Program | $(echo "$cfgs" | sed 's/ / | /g') |"
echo "|---|$(for c in $cfgs; do printf -- '---:|'; done)"
gclines=""
for name in $programs; do
  line="| $name |"
  base=""
  for c in $cfgs; do
    cmd=$(command_of "$c" "$name") || { line="$line n/a |"; continue; }
    # shellcheck disable=SC2086
    got=$(measure "$name.$c" $cmd) || { line="$line FAIL |"; continue; }
    if [ -f "tests/perf/$name.expected" ] && [ -z "$bench_dir" ] && ! grep -q -x -F -f "tests/perf/$name.expected" "$out/$name.$c.stdout"; then
      line="$line WRONG |"; continue
    fi
    cycles=${got%% *}
    instrs=${got#* }
    [ -z "$base" ] && base=$cycles
    ratio=$(awk "BEGIN { printf \"%.2f\", $cycles / $base }")
    line="$line $(human "$cycles") cycles, $(human "$instrs") instr. ($ratio) |"
    stats=""
    if [ $gc = 1 ]; then
      stats=$(gc_stats "$name.$c")
      set -- $stats
      [ -n "$stats" ] && gclines="$gclines
| $name | $c | $1 | $(human "$2") | $(awk "BEGIN { printf \"%.1f\", $3 / 1000 }") ms | $(human "$4") |"
    fi
    echo "$name $c $cycles $instrs $(counters "$name.$c")$(echo "$stats" | awk 'NF == 4 { printf "collections=%s copied=%s gc_us=%s semispace=%s", $1, $2, $3, $4 }')" >> "$out/numbers.txt"
  done
  echo "$line"
done
if [ $gc = 1 ]; then
  echo
  echo "| Program | Configuration | Collections | Copied | GC time | Semispace |"
  echo "|---|---|---:|---:|---:|---:|$gclines"
fi

if [ -n "$profile" ]; then
  pconfig=${profile%%:*}
  pprog=bootstrap
  case "$profile" in *:*) pprog=${profile#*:} ;; esac
  cmd=$(command_of "$pconfig" "$pprog") || { echo "perf-cycles: cannot build $pprog in $pconfig" >&2; exit 1; }
  # the JIT's functions named in the report (--jit-perf-map, M7)
  case "$pconfig" in new|jit*) cmd=$(echo "$cmd" | sed 's|^\([^ ]*\) |\1 --jit-perf-map |') ;; esac
  graph=""
  frame_pointers "${cmd%% *}" && graph="--call-graph fp"
  # shellcheck disable=SC2086
  "$perf" record -e cycles:u $graph -o "$out/$pprog.$pconfig.data" -- $cmd > /dev/null 2> "$out/$pprog.$pconfig.record.err" || exit 1
  echo
  echo "$pprog in $pconfig, by symbol (perf record${graph:+, $graph}):"
  echo
  "$perf" report -i "$out/$pprog.$pconfig.data" --stdio --no-children -g none --sort symbol --percent-limit 0.3 2> /dev/null | grep -v '^#' | grep -v '^$' | head -25
  # where the time goes, by group (scripts/perf-groups.awk): the collector
  # with memcpy called from copy_obj, allocation, dispatch, the primitives,
  # JIT and native code; the callchains of a frame-pointer build tell the
  # caller of memcpy, else it counts as "memmove/memcpy (other callers)"
  echo
  echo "$pprog in $pconfig, by group (percent of samples):"
  echo
  "$perf" script -i "$out/$pprog.$pconfig.data" -F period,ip,sym,dso 2> /dev/null | awk -v top=12 -f scripts/perf-groups.awk | awk -F'\t' '$1 == "group" && $3 + 0 >= 0.05 { printf "  %-40s %6.2f%%\n", $2, $3 } $1 == "sym" { printf "    %-38s %6.2f%%\n", $2, $3 }'
fi

# --sweep: the heap-size sweep (DaCapo's method) of every program in every
# configuration; rows of tests/out/cycles/sweep.txt:
#   program config k requested semispace collections copied gc_us live cycles instructions task_clock page_faults
if [ $sweep = 1 ]; then
  : > "$out/sweep.txt"
  echo
  echo "| Program | Configuration | Heap | Semispace | Collections | Copied | GC time | Cycles | Task-clock | Faults |"
  echo "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|"
  # sweep_stats LABEL: "collections semispace live copied max_live gc_us" of the run that counts
  sweep_stats() {
    sed -n 's/^runevm: \([0-9]*\) collections, [0-9]* bytes allocated, semispace \([0-9]*\) bytes, \([0-9]*\) live, copied \([0-9]*\), max live \([0-9]*\), gc \([0-9]*\) us$/\1 \2 \3 \4 \5 \6/p' "$out/$1.best.stderr" | tail -1
  }
  # sweep_counter LABEL EVENT: that counter of the run that counts
  sweep_counter() { sed -n "s/^\([0-9]*\),[^,]*,$2,.*/\1/p" "$out/$1.best.perf" | head -1; }
  # sweep_point PROGRAM CONFIG K OPTS: one measurement, a row of the table and of sweep.txt
  sweep_point() {
    vmopts="$4 --stats"
    export RUNEVM_OPTIONS="$vmopts"
    cmd=$(command_of "$2" "$1") || return 1
    # shellcheck disable=SC2086
    got=$(measure "$1.$2" $cmd) || return 1
    st=$(sweep_stats "$1.$2"); set -- $st "$1" "$2" "$3" "$4"
    [ -n "$st" ] || return 1
    tc=$(sweep_counter "$7.$8" task-clock:u); pf=$(sweep_counter "$7.$8" page-faults:u)
    echo "$7 $8 $9 $(echo "${10}" | sed -n 's/.*--heap-size \([0-9]*\).*/\1/p') $1 $4 $6 $3 ${got%% *} ${got#* } ${tc:-0} ${pf:-0}" >> "$out/sweep.txt"
    echo "| $7 | $8 | $9 | $(human "$2") | $1 | $(human "$4") | $(awk "BEGIN { printf \"%.1f\", $6 / 1000 }") ms | $(human "${got%% *}") | $(awk "BEGIN { printf \"%.1f\", ${tc:-0} / 1000000 }") ms | ${pf:-0} |"
    echo "$5"
  }
  for name in $programs; do
    for c in $cfgs; do
      L=$(sweep_point "$name" "$c" "L (fill 99 from 4 MiB)" "--heap-fill 99 --heap-size 4194304" | tail -1)
      [ -n "$L" ] && [ "$L" -gt 0 ] 2> /dev/null || { echo "| $name | $c | no live data: nothing to sweep | | | | | | | |"; continue; }
      for k in 1.25 1.5 2 3 4 6 8 2GiB; do
        if [ "$k" = 2GiB ]; then size=2147483648; else size=$(awk "BEGIN { printf \"%d\", $k * $L }"); fi
        sweep_point "$name" "$c" "$k" "--heap-fill 100 --heap-size $size" | sed '$d'
      done
    done
  done
fi
