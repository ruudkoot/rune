#!/bin/sh
# Run the Basis Library suite (tests/basis/*.sml) on a matrix of configurations.
#   tests/basis/run-matrix.sh [-j N] [--configs C1,C2,...] [FILTER]
#   tests/basis/run-matrix.sh --perf [--configs C1,C2,...] [FILTER]
#
# Configurations (default: rune):
#   rune                   bin/rune, the self-hosted compiler, + bin/runevm
#                          (override: RUNE=, RUNEVM=; both must be absolute)
#   native:mlton  native:smlnj  native:polyml
#                          the suite against the host's own Basis Library,
#                          with the installed host (override: MLTON=, SMLNJ=, POLY=)
#   xc1:mlton  xc1:smlnj  xc1:polyml
#                          the suite against Rune's Basis Library (lib/basis)
#                          compiled by the host; see below
#   native:HOST@cur  xc1:HOST@cur
#                          the same with the current release that
#                          scripts/fetch-hosts.sh installed under
#                          ${RUNE_HOSTS:-$HOME/.local/rune-hosts}
#   installed              rune and native:HOST for the three installed hosts
#   xc1                    xc1:HOST for the three installed hosts
#   current                native:HOST@cur and xc1:HOST@cur
#   all                    installed, xc1 and current
# A configuration is reported under an id that carries the version of the
# host, e.g. native:smlnj@110.79; tests/basis/deviations.txt matches on it.
#
# A test program is harness.sml + the files named in the test's
# `(* uses: spec-sigs/LIST.sml ... *)` header (relative to tests/basis) + the
# test + finish.sml. It prints one
# "PASS label" or "FAIL label -- why" line per check and ends with a SUMMARY
# line. When a test does not load in a configuration:
#  * a structure named in its `(* requires: A B *)` header that the
#    configuration lacks makes the test ABSENT there;
#  * otherwise each of its sections, the lines between `(*<< name *)` and
#    `(*>> name *)`, is tried by itself; those that do not load are left out
#    and count as the failed check @section/TEST/NAME;
#  * a test that still does not load counts as the failed check @load/TEST,
#    and so does one that runs for more than RUNE_MATRIX_TIMEOUT seconds
#    (default 120), which is not tried again without its sections.
#
# An xc1 program starts with structure RunePrim, the primitives of
# vm/prims.def written on the host's Basis Library, and the files of lib/basis
# (tests/basis/host/gen-host-basis.sh). A file of lib/basis that the host does
# not accept is left out, with the files that do not load without it, and the
# structures it declares remain the host's. A test that `requires` such a
# structure is N/A in the configuration, never a pass: it would test the host.
# The top-level values of the host are hidden for the same reason.
# MLton compiles xc1 programs with 64-bit int and word, the types of the VM.
#
# Every failed check must be explained by a line of tests/basis/deviations.txt,
#   config-glob | label-glob | CATEGORY | reason
# A RUNE-DEV or SPEC-AMBIGUOUS line for the configuration `rune` also explains
# the same failure in an xc1 configuration, which shares the library source.
# Exit status 1: an unexplained failure, or a line that matches no failure of
# a configuration it names (so the file never goes stale; not checked when a
# FILTER is given). A test that is ABSENT for the rune configuration is the
# failed check @absent/TEST, to be explained likewise: Rune's library is
# meant to be complete.
#
# --perf times the programs of tests/perf instead (`make perf`), one at a
# time, in the same configurations. A program's top-level declarations become
# the body of a function that is called R times, R from the `wall R` line of
# its .budget file (default 1), so what is timed is running the program, not
# compiling it, on every host; of three such rounds the fastest counts. Each run must print what NAME.expected holds.
# The table in tests/out/perf/wall.md gives the milliseconds of one run and
# each time divided by the baseline of its configuration, the geometric mean
# of fib and tak, which use no Basis Library: that separates what the library
# costs from how fast the configuration runs code at all. A program is n/a
# in an xc1 configuration when its .budget file has a line `noxc1 REASON`,
# when it names a structure whose file the host left out, or when the host's
# int is too narrow for the Time of lib/basis. A host that fails a program
# is reported under the table; only a failure of `rune` fails the run.
set -u

jobs=""
perf=${RUNE_MATRIX_PERF:-0}
configs=rune
filter=""
one_config=""
one_test=""
while [ $# -gt 0 ]; do
  case "$1" in
    -j) jobs=$2; shift 2 ;;
    --configs) configs=$2; shift 2 ;;
    --one) one_config=$2; one_test=$3; shift 3 ;;
    --perf) perf=1; shift ;;
    -*) echo "usage: tests/basis/run-matrix.sh [-j N] [--perf] [--configs C1,C2,...] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done

self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
cd "$(dirname "$0")/../.."
root=$(pwd)
suite=$root/tests/basis
out=$root/tests/out/matrix
limit=${RUNE_MATRIX_TIMEOUT:-120}
mkdir -p "$out"
# Files of this invocation (several may run at once, on different tests).
run=${RUNE_MATRIX_RUN:-$out/run.$$}

dirname_of() { echo "$1" | tr ':@/' '---'; }

# ------------------------------------------------------------------ worker
# The table $out/configs maps an id to "kind host command...".
config_field() { awk -F '\t' -v id="$1" -v n="$2" '$1 == id { print $n }' "$run/configs"; }

# first_error FILE...: the line that best explains why a program did not load
# (not a declaration that an interactive system echoes, like `val file_error`).
first_error() {
  cat "$@" 2> /dev/null | grep -v -E '^PASS |^\[opening |^[[:space:]]*(val|exception|type|datatype|structure|signature) ' |
    grep -i -m 1 -E 'error|exception|raised|timed out' | cut -c 1-300
}

# write_driver FILE SOURCES...: a `use` chain that exits with a failure status
# when a file does not load (SML/NJ and Poly/ML).
write_driver() {
  driver=$1
  shift
  {
    printf '('
    sep=""
    for f in "$@"; do printf '%suse "%s"' "$sep" "$f"; sep="; "; done
    printf ') handle e => (print ("uncaught exception " ^ exnName e ^ " [" ^ exnMessage e ^ "]\\n"); OS.Process.exit OS.Process.failure);\n'
  } > "$driver"
}

# write_mlb FILE SOURCES...
write_mlb() {
  mlb=$1
  shift
  {
    echo '$(SML_LIB)/basis/basis.mlb'
    for f in "$@"; do printf '"%s"\n' "$f"; done
  } > "$mlb"
}

# sh has no local variables: a function that is called while its caller's
# variables are live uses names of its own (loaddir, candidate).
#
# load WORK MODE SOURCES...: compile and (MODE=run) run the program made of
# SOURCES in directory WORK. Leaves stdout in $WORK/stdout and everything else
# in $WORK/log. With MODE=check the program is only type-checked where the
# configuration can do that. Succeeds iff the program loaded: for MODE=run,
# iff it printed its SUMMARY line.
load() {
  loaddir=$1
  mode=$2
  shift 2
  rm -rf "$loaddir"
  mkdir -p "$loaddir"
  : > "$loaddir/stdout"
  : > "$loaddir/log"
  case "$kind:$host" in
    rune:*)
      if [ "$mode" = check ]; then
        "$cmd1" --typecheck-only "$@" > "$loaddir/log" 2>&1
        return
      fi
      "$cmd1" "$@" -o "$loaddir/prog.rbc" > "$loaddir/log" 2>&1 || return 1
      (cd "$loaddir" && timeout "$limit" "$cmd2" prog.rbc > stdout 2>> log < /dev/null)
      ;;
    *:mlton)
      write_mlb "$loaddir/prog.mlb" "$@"
      flags=""
      [ "$kind" = xc1 ] && flags="-default-type int64 -default-type word64"
      if [ "$mode" = check ]; then
        # shellcheck disable=SC2086
        "$cmd1" $flags -stop tc "$loaddir/prog.mlb" > "$loaddir/log" 2>&1
        return
      fi
      # shellcheck disable=SC2086
      timeout "$limit" "$cmd1" $flags -output "$loaddir/prog" "$loaddir/prog.mlb" > "$loaddir/log" 2>&1 || return 1
      (cd "$loaddir" && timeout "$limit" ./prog > stdout 2>> log < /dev/null)
      ;;
    *:smlnj)
      write_driver "$loaddir/driver.sml" "$@"
      (cd "$loaddir" && timeout "$limit" "$cmd1" driver.sml > stdout 2> log < /dev/null)
      ;;
    *:polyml)
      write_driver "$loaddir/driver.sml" "$@"
      (cd "$loaddir" && timeout "$limit" "$cmd1" -q --error-exit --use driver.sml > stdout 2> log < /dev/null)
      ;;
    *) echo "unknown configuration kind $kind:$host" > "$loaddir/log"; return 1 ;;
  esac
  status=$?
  [ $status = 124 ] && echo "timed out after $limit s" >> "$loaddir/log"
  grep -q '^SUMMARY ' "$loaddir/stdout"
}

# prefix: the files every program of the configuration starts with.
prefix() {
  [ "$kind" = xc1 ] || return 0
  cat "$cfgout/basis/prelude" "$cfgout/basis.loaded"
}

# has_structure NAME: the configuration has a structure NAME (cached).
has_structure() {
  cache=$cfgout/probe/$1
  if [ ! -f "$cache" ]; then
    mkdir -p "$cfgout/probe"
    probe=$cfgout/probe/$1.$$.dir
    mkdir -p "$probe"
    echo "structure Probe__ = $1" > "$probe/probe.sml"
    # shellcheck disable=SC2046
    if load "$probe/work" run $(prefix) "$suite/harness.sml" "$probe/probe.sml" "$suite/finish.sml"; then echo yes; else echo no; fi > "$cache.$$"
    mv "$cache.$$" "$cache"
    rm -rf "$probe"
  fi
  [ "$(cat "$cache")" = yes ]
}

# variant SRC DEST KEEP: copy SRC, blanking the sections not named in KEEP
# (line numbers are preserved).
variant() {
  awk -v keep=" $3 " '
    /^[ \t]*\(\*<< / { name = $2; blank = (index(keep, " " name " ") == 0); print ""; next }
    /^[ \t]*\(\*>> / { blank = 0; print ""; next }
    { if (blank) print ""; else print }
  ' "$1" > "$2"
}

# sources TEST-SOURCE: the files of the program that runs TEST-SOURCE.
sources() {
  prefix
  echo "$suite/harness.sml"
  for u in $uses; do echo "$suite/$u"; done
  echo "$1"
  echo "$suite/finish.sml"
}

run_one() {
  config=$1
  test=$2
  kind=$(config_field "$config" 2)
  host=$(config_field "$config" 3)
  cmd1=$(config_field "$config" 4)
  cmd2=$(config_field "$config" 5)
  cfgout=$out/$(dirname_of "$config")
  src=$suite/$test.sml
  work=$cfgout/$test.dir
  result=$cfgout/$test.result
  mkdir -p "$cfgout"
  : > "$result.tmp"
  uses=$(sed -n 's/^(\* uses: \(.*\) \*)$/\1/p' "$src")
  requires=$(sed -n 's/^(\* requires: \(.*\) \*)$/\1/p' "$src")

  if [ "$kind" = xc1 ]; then
    # A required structure that is not Rune's here: one that lib/basis lacks
    # is ABSENT as it is for rune, one whose file the host left out is N/A.
    for m in $requires; do
      grep -q -x "$m" "$cfgout/basis.provides" && continue
      if cut -f 2 "$cfgout/basis/files" | tr ' ' '\n' | grep -q -x "$m"; then echo "NA $m"; else echo "ABSENT $m"; fi >> "$result.tmp"
    done
    if [ -s "$result.tmp" ]; then
      mv "$result.tmp" "$result"
      return
    fi
  fi

  final=$src
  # shellcheck disable=SC2046
  if ! load "$work" run $(sources "$src"); then
    why=$(first_error "$work/log" "$work/stdout")
    if grep -q '^timed out after ' "$work/log"; then
      grep -E '^(PASS|FAIL) ' "$work/stdout" >> "$result.tmp"
      echo "FAIL @load/$test -- timed out after $limit s" >> "$result.tmp"
      mv "$result.tmp" "$result"
      return
    fi
    # 1. structures the configuration lacks
    absent=""
    for m in $requires; do
      has_structure "$m" || absent="$absent $m"
    done
    if [ -n "$absent" ]; then
      for m in $absent; do echo "ABSENT $m" >> "$result.tmp"; done
      mv "$result.tmp" "$result"
      return
    fi
    # 2. sections that do not load
    sections=$(awk '/^[ \t]*\(\*<< / { print $2 }' "$src")
    final=""
    if [ -n "$sections" ]; then
      variant "$src" "$cfgout/$test.base.sml" ""
      # shellcheck disable=SC2046
      if load "$work" check $(sources "$cfgout/$test.base.sml"); then
        keep=""
        for s in $sections; do
          variant "$src" "$cfgout/$test.try.sml" "$s"
          # shellcheck disable=SC2046
          if load "$work" check $(sources "$cfgout/$test.try.sml"); then
            keep="$keep $s"
          else
            echo "FAIL @section/$test/$s -- $(first_error "$work/log" "$work/stdout")" >> "$result.tmp"
          fi
        done
        final=$cfgout/$test.final.sml
        variant "$src" "$final" "$keep"
        # shellcheck disable=SC2046
        if ! load "$work" run $(sources "$final"); then
          why=$(first_error "$work/log" "$work/stdout")
          final=""
        fi
      else
        why=$(first_error "$work/log" "$work/stdout")
      fi
    fi
    if [ -z "$final" ]; then
      # Checks that ran before the failure are still reported.
      grep -E '^(PASS|FAIL) ' "$work/stdout" >> "$result.tmp"
      echo "FAIL @load/$test -- ${why:-did not load}" >> "$result.tmp"
      mv "$result.tmp" "$result"
      return
    fi
  fi

  grep -E '^(PASS|FAIL) ' "$work/stdout" >> "$result.tmp"
  claimed=$(sed -n 's/^SUMMARY \([0-9]*\) checks.*/\1/p' "$work/stdout")
  counted=$(grep -c -E '^(PASS|FAIL) ' "$work/stdout")
  if [ "$claimed" != "$counted" ]; then
    echo "FAIL @load/$test -- SUMMARY reports $claimed checks but $counted were printed" >> "$result.tmp"
  fi
  dups=$(grep -E '^(PASS|FAIL) ' "$work/stdout" | awk '{ print $2 }' | sort | uniq -d | head -3 | tr '\n' ' ')
  [ -z "$dups" ] || echo "FAIL @load/$test -- duplicate check labels: $dups" >> "$result.tmp"
  mv "$result.tmp" "$result"
}

# wall_program NAME R FILE KIND: tests/perf/NAME.sml as the body of a function
# that FILE calls R times between reading and printing a real-time timer.
# CommandLine is shadowed: a host's own arguments are not the program's.
# The Time of lib/basis counts microseconds since 1970 in an int, which an
# xc1 host with a narrow int cannot do: the program then prints NA. (A host's
# own Time has no such limit.)
wall_program() {
  {
    echo 'structure CommandLine = struct fun name () = "bench" fun arguments () : string list = [] end'
    echo 'fun runeWallBody__ () = let'
    cat "$root/tests/perf/$1.sml"
    echo 'in () end'
    if [ "$4" = xc1 ]; then
      echo 'val () ='
      echo '  case Int.precision of'
      printf '%s\n' '    SOME p => if p < 52 then print ("NA the int has " ^ Int.toString p ^ " bits, Time needs 52\n") else ()'
      echo '  | NONE => ()'
      echo 'val runeWallRun__ = case Int.precision of SOME p => p >= 52 | NONE => true'
    else
      echo 'val runeWallRun__ = true'
    fi
    # three rounds of R runs; the fastest round is the measurement
    echo "fun runeWallRound__ () = let val t = Timer.startRealTimer () fun loop 0 = () | loop k = (runeWallBody__ (); loop (k - 1))"
    echo "  in loop $2; Time.toMicroseconds (Timer.checkRealTimer t) end"
    printf '%s\n' 'val () = if runeWallRun__ then let val a = runeWallRound__ () val b = runeWallRound__ () val c = runeWallRound__ ()'
    printf '%s\n' '  in print ("TIME " ^ LargeInt.toString (LargeInt.min (a, LargeInt.min (b, c))) ^ "\n") end else ()'
    printf '%s\n' 'val () = print "SUMMARY 0 checks\n"'
  } > "$3"
}

# perf_one CONFIG NAME: time tests/perf/NAME.sml in CONFIG; the result is
# "TIME microseconds", "NA structure" or "FAIL why".
perf_one() {
  config=$1
  test=$2
  kind=$(config_field "$config" 2)
  host=$(config_field "$config" 3)
  cmd1=$(config_field "$config" 4)
  cmd2=$(config_field "$config" 5)
  cfgout=$out/$(dirname_of "$config")
  work=$cfgout/perf-$test.dir
  result=$cfgout/perf-$test.result
  mkdir -p "$cfgout"
  if [ "$kind" = xc1 ]; then
    why=$(sed -n 's/^noxc1 //p' "$root/tests/perf/$test.budget")
    if [ -n "$why" ]; then echo "NA $why" > "$result"; return; fi
    for m in $(cut -f 1 "$cfgout/basis.dropped" | while read -r f; do awk -F '\t' -v f="$f" '{ n = split($1, p, "/"); if (p[n] == f) print $2 }' "$cfgout/basis/files"; done); do
      if grep -q -w "$m" "$root/tests/perf/$test.sml"; then echo "NA $m" > "$result"; return; fi
    done
  fi
  reps=$(sed -n 's/^wall //p' "$root/tests/perf/$test.budget")
  reps=${reps:-1}
  mkdir -p "$cfgout/perf"
  wall_program "$test" "$reps" "$cfgout/perf/$test.sml" "$kind"
  # shellcheck disable=SC2046
  if ! load "$work" run $(prefix) "$cfgout/perf/$test.sml"; then
    echo "FAIL $(first_error "$work/log" "$work/stdout")" > "$result"
    return
  fi
  if grep -q '^NA ' "$work/stdout"; then
    grep '^NA ' "$work/stdout" | head -1 > "$result"
    return
  fi
  # An interactive host echoes its declarations: count the expected lines.
  want=$(wc -l < "$root/tests/perf/$test.expected")
  got=$(grep -c -x -F -f "$root/tests/perf/$test.expected" "$work/stdout")
  if [ "$got" != $((want * reps * 3)) ]; then
    echo "FAIL printed $(grep -v -E '^(TIME|SUMMARY) ' "$work/stdout" | head -1), expected $(head -1 "$root/tests/perf/$test.expected") $((reps * 3)) times" > "$result"
    return
  fi
  echo "TIME $(sed -n 's/^TIME //p' "$work/stdout") $reps" > "$result"
}

if [ -n "$one_config" ]; then
  if [ "$perf" = 1 ]; then perf_one "$one_config" "$one_test"; else run_one "$one_config" "$one_test"; fi
  exit 0
fi

# ------------------------------------------------------------------ configurations
hosts_prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}

expand() {
  for c in $(echo "$1" | tr ',' ' '); do
    case "$c" in
      installed) echo rune native:mlton native:smlnj native:polyml ;;
      xc1) echo xc1:mlton xc1:smlnj xc1:polyml ;;
      current) echo native:mlton@cur native:smlnj@cur native:polyml@cur xc1:mlton@cur xc1:smlnj@cur xc1:polyml@cur ;;
      all) expand installed,xc1,current ;;
      *) echo "$c" ;;
    esac
  done
}

# resolve CONFIG: append "id kind host cmd1 cmd2" to $out/configs.
resolve() {
  spec=$1
  gen=installed
  case "$spec" in *@cur) gen=cur; spec=${spec%@cur} ;; esac
  kind=${spec%%:*}
  host=""
  [ "$kind" = "$spec" ] || host=${spec#*:}
  cmd2=""
  case "$kind:$host" in
    rune:)
      cmd1=${RUNE:-$root/bin/rune}
      cmd2=${RUNEVM:-$root/bin/runevm}
      id=rune
      [ -x "$cmd1" ] && [ -x "$cmd2" ] || { echo "run-matrix: $cmd1 or $cmd2 is missing (run make)" >&2; return 1; }
      ;;
    native:mlton|xc1:mlton)
      if [ $gen = cur ]; then cmd1=$hosts_prefix/mlton/bin/mlton; else cmd1=${MLTON:-mlton}; fi
      version=$("$cmd1" 2> /dev/null | sed -n '1s/^MLton \([0-9][0-9.]*\).*/\1/p')
      ;;
    native:smlnj|xc1:smlnj)
      if [ $gen = cur ]; then cmd1=$hosts_prefix/smlnj/bin/sml; else cmd1=${SMLNJ:-sml}; fi
      version=$("$cmd1" @SMLversion 2> /dev/null | sed -n '1s/^sml \([0-9][0-9.]*\).*/\1/p')
      ;;
    native:polyml|xc1:polyml)
      if [ $gen = cur ]; then cmd1=$hosts_prefix/polyml/bin/poly; else cmd1=${POLY:-poly}; fi
      version=$("$cmd1" -v 2> /dev/null | sed -n '1s/^Poly\/ML \([0-9][0-9.]*\).*/\1/p')
      ;;
    *) echo "run-matrix: unknown configuration '$1'" >&2; return 1 ;;
  esac
  if [ "$kind" != rune ]; then
    if [ -z "$version" ]; then
      echo "run-matrix: cannot run $cmd1 for configuration '$1'$([ $gen = cur ] && echo ' (make hosts installs the current releases)')" >&2
      return 1
    fi
    id=$kind:$host@$version
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$id" "$kind" "$host" "$cmd1" "$cmd2" >> "$run/configs"
}

mkdir -p "$run"
trap 'rm -rf "$run"' EXIT HUP INT TERM
: > "$run/configs"
for c in $(expand "$configs"); do resolve "$c" || exit 2; done
ids=$(cut -f 1 "$run/configs")

tests=""
if [ "$perf" = 1 ]; then
  for f in "$root"/tests/perf/*.expected; do
    name=$(basename "$f" .expected)
    case "$name" in *"$filter"*) tests="$tests $name" ;; esac
  done
else
  for f in "$suite"/*.sml; do
    name=$(basename "$f" .sml)
    case "$name" in harness|finish) continue ;; esac
    case "$name" in *"$filter"*) tests="$tests $name" ;; esac
  done
fi
[ -n "$tests" ] || { echo "run-matrix: no test matches '$filter'" >&2; exit 2; }

[ -n "$jobs" ] || jobs=$(sh scripts/ncpus.sh)
for id in $ids; do
  d=$out/$(dirname_of "$id")
  mkdir -p "$d"
  for t in $tests; do rm -f "$d/$t.result"; done
  # What a host has does not change between runs; what Rune's library has does.
  case "$id" in
    rune|xc1:*) rm -rf "$d/probe" ;;
    *) [ -n "$filter" ] || rm -rf "$d/probe" ;;
  esac
done

# probe_basis ID: generate the library sources of xc1 configuration ID and
# find the files of lib/basis that load on its host, in
#   basis.loaded    their paths, in load order
#   basis.provides  the structures they declare
#   basis.dropped   "FILE<TAB>first error" for the others
probe_basis() {
  kind=xc1
  host=$(config_field "$1" 3)
  cmd1=$(config_field "$1" 4)
  cfgout=$out/$(dirname_of "$1")
  gen=$cfgout/basis
  rm -rf "$gen"
  sh tests/basis/host/gen-host-basis.sh "$gen" || return 1
  printf '%s\n' 'val () = TextIO.print "SUMMARY loaded\n"' > "$gen/ok.sml"
  prelude=$(cat "$gen/prelude")
  # shellcheck disable=SC2086
  if ! load "$cfgout/basis.work" check $prelude "$gen/ok.sml"; then
    echo "run-matrix: $1: tests/basis/host/rune-prim.sml does not load: $(first_error "$cfgout/basis.work/log" "$cfgout/basis.work/stdout")" >&2
    return 1
  fi
  all=$(cut -f 1 "$gen/files")
  : > "$cfgout/basis.dropped"
  # shellcheck disable=SC2086
  if load "$cfgout/basis.work" check $prelude $all "$gen/ok.sml"; then
    accepted=$all
  else
    accepted=""
    # (load and its helpers use f: sh has no local variables)
    for candidate in $all; do
      # shellcheck disable=SC2086
      if load "$cfgout/basis.work" check $prelude $accepted "$candidate" "$gen/ok.sml"; then
        accepted="$accepted $candidate"
      else
        printf '%s\t%s\n' "$(basename "$candidate")" "$(first_error "$cfgout/basis.work/log" "$cfgout/basis.work/stdout")" >> "$cfgout/basis.dropped"
      fi
    done
  fi
  : > "$cfgout/basis.loaded"
  : > "$cfgout/basis.provides"
  for f in $accepted; do
    echo "$f" >> "$cfgout/basis.loaded"
    awk -F '\t' -v f="$f" '$1 == f { n = split($2, m, " "); for (i = 1; i <= n; i++) print m[i] }' "$gen/files" >> "$cfgout/basis.provides"
  done
  rm -rf "$cfgout/basis.work"
}

pids=""
for id in $ids; do
  case "$id" in xc1:*) probe_basis "$id" & pids="$pids $!" ;; esac
done
for pid in $pids; do wait "$pid" || exit 2; done
if [ "$perf" = 1 ]; then
  # One at a time: a timing is only worth something on an idle machine.
  for id in $ids; do for t in $tests; do printf '%s\n%s\n' "$id" "$t"; done; done |
    RUNE_MATRIX_RUN=$run RUNE_MATRIX_PERF=1 xargs -n 2 -P 1 sh "$self" --one
  wall=$root/tests/out/perf/wall.md
  mkdir -p "$root/tests/out/perf"
  status=0
  # cell ID NAME: "ms" of one run, n/a, or error (the reason goes to
  # stderr, and so does why a cell is n/a)
  cell() {
    r=$out/$(dirname_of "$1")/perf-$2.result
    if [ ! -f "$r" ]; then echo error; echo "error $1 $2: no result" >&2; return; fi
    case "$(cut -d ' ' -f 1 "$r")" in
      TIME) awk '{ printf "%.2f", $2 / $3 / 1000 }' "$r" ;;
      NA) echo n/a; echo "n/a $1 $2: $(cut -d ' ' -f 2- "$r")" >&2 ;;
      *) echo error; echo "error $1 $2: $(cut -d ' ' -f 2- "$r")" >&2 ;;
    esac
  }
  {
    echo "# Wall-clock times"
    echo
    echo "Milliseconds of one run of each program of tests/perf, on $(uname -m) with $(sh scripts/ncpus.sh) CPUs, $(date -u +%Y-%m-%d)."
    echo "In parentheses: the time divided by the baseline of the configuration (the geometric mean of fib and tak)."
    echo
    printf '| Program |'; for id in $ids; do printf ' %s |' "$id"; done; echo
    printf '|---|'; for id in $ids; do printf '%s' '---:|'; done; echo
    for t in $tests; do
      printf '| %s |' "$t"
      for id in $ids; do
        v=$(cell "$id" "$t" 2>> "$run/perf-errors")
        base=$(awk -v a="$(cell "$id" fib 2> /dev/null)" -v b="$(cell "$id" tak 2> /dev/null)" 'BEGIN { if (a + 0 > 0 && b + 0 > 0) printf "%.3f", sqrt(a * b) }')
        case "$v" in
          error|n/a) printf ' %s |' "$v" ;;
          *) if [ -n "$base" ]; then printf ' %s (%s) |' "$v" "$(awk -v v="$v" -v b="$base" 'BEGIN { printf "%.1f", v / b }')"; else printf ' %s |' "$v"; fi ;;
        esac
      done
      echo
    done
  } > "$wall"
  if [ -s "$run/perf-errors" ]; then
    { echo
      echo "Not measured:"
      echo
      sort -u "$run/perf-errors" | sed 's/^/* /'
    } >> "$wall"
  fi
  cat "$wall"
  # A host that cannot run a program is reported; Rune that cannot fails.
  grep -q '^error rune ' "$run/perf-errors" 2> /dev/null && status=1
  echo "table: ${wall#"$root"/}"
  exit $status
fi
for id in $ids; do for t in $tests; do printf '%s\n%s\n' "$id" "$t"; done; done |
  RUNE_MATRIX_RUN=$run xargs -n 2 -P "$jobs" sh "$self" --one

# ------------------------------------------------------------------ report
dev=$run/deviations.norm
if [ -f "$suite/deviations.txt" ]; then
  grep -n '' "$suite/deviations.txt" | grep -v -E '^[0-9]+:[[:space:]]*(#|$)' |
    sed -e 's/[[:space:]]*|[[:space:]]*/|/g' -e 's/^\([0-9]*\):[[:space:]]*/\1|/' > "$dev"
else
  : > "$dev"
fi

# explain CONFIG LABEL: print "LINE|CATEGORY|reason" of the first matching
# deviation; LINE is 0 for a line of `rune` that an xc1 configuration inherits,
# which the check for stale lines does not count.
explain() {
  while IFS='|' read -r line cglob lglob category reason; do
    # shellcheck disable=SC2254
    case "$1" in
      $cglob) ;;
      xc1:*)
        [ "$cglob" = rune ] || continue
        case "$category" in RUNE-DEV|SPEC-AMBIGUOUS) line=0 ;; *) continue ;; esac
        ;;
      *) continue ;;
    esac
    # shellcheck disable=SC2254
    case "$2" in $lglob) echo "$line|$category|$reason"; return ;; esac
  done < "$dev"
}

report=$out/report${filter:+-$filter}.md
unexplained=$run/unexplained.txt
used=$run/deviations.used
: > "$unexplained"
: > "$used"
{
  echo "# Basis Library suite"
  echo
  echo "| Configuration | Test | Checks | Pass | Explained | Unexplained | Not run |"
  echo "|---|---|---|---|---|---|---|"
} > "$report"
xfails=$run/xfail.txt
: > "$xfails"
status=0

for id in $ids; do
  d=$out/$(dirname_of "$id")
  t_checks=0; t_pass=0; t_xfail=0; t_fail=0; t_absent=0; t_na=0
  for t in $tests; do
    r=$d/$t.result
    if [ ! -f "$r" ]; then
      echo "$id @load/$t -- no result" >> "$unexplained"
      t_fail=$((t_fail + 1))
      continue
    fi
    pass=$(grep -c '^PASS ' "$r")
    absent=$(sed -n 's/^ABSENT //p' "$r" | tr '\n' ' ')
    na=$(sed -n 's/^NA //p' "$r" | tr '\n' ' ')
    xfail=0
    fail=0
    grep '^FAIL ' "$r" > "$d/$t.fails"
    while read -r _ label rest; do
      e=$(explain "$id" "$label")
      if [ -n "$e" ]; then
        xfail=$((xfail + 1))
        echo "${e%%|*} $id" >> "$used"
        printf '%s\n' "$id|$label|${e#*|}" >> "$xfails"
      else
        fail=$((fail + 1))
        printf '%s\n' "$id $label $rest" >> "$unexplained"
      fi
    done < "$d/$t.fails"
    echo "| $id | $t | $((pass + xfail + fail)) | $pass | $xfail | $fail | ${absent:+absent: $absent}${na:+n/a: $na}|" >> "$report"
    t_checks=$((t_checks + pass + xfail + fail)); t_pass=$((t_pass + pass))
    t_xfail=$((t_xfail + xfail)); t_fail=$((t_fail + fail))
    [ -z "$na" ] || t_na=$((t_na + 1))
    if [ -n "$absent" ]; then
      t_absent=$((t_absent + 1))
      if [ "$id" = rune ]; then
        e=$(explain "$id" "@absent/$t")
        if [ -n "$e" ]; then
          echo "${e%%|*} $id" >> "$used"
          echo "$id|@absent/$t|${e#*|}" >> "$xfails"
        else
          echo "$id @absent/$t -- lacks $absent" >> "$unexplained"
          t_fail=$((t_fail + 1))
        fi
      fi
    fi
  done
  printf '%-28s %6d checks: %6d pass, %4d explained, %4d FAILED; of %d tests %d absent, %d n/a\n' \
    "$id" "$t_checks" "$t_pass" "$t_xfail" "$t_fail" "$(echo $tests | wc -w)" "$t_absent" "$t_na"
done

if [ -s "$unexplained" ]; then
  status=1
  echo "unexplained failures (add a fix, or a line to tests/basis/deviations.txt):"
  head -40 "$unexplained" | sed 's/^/  /'
  n=$(wc -l < "$unexplained")
  [ "$n" -le 40 ] || echo "  ... and $((n - 40)) more in ${report#"$root"/}"
fi

# Stale deviations: a line must match a failure in every configuration of
# this run that its configuration glob names (not a HOST-FLAKY line: that
# failure comes and goes).
if [ -z "$filter" ]; then
  while IFS='|' read -r line cglob lglob category reason; do
    [ "$category" = HOST-FLAKY ] && continue
    for id in $ids; do
      # shellcheck disable=SC2254
      case "$id" in $cglob) ;; *) continue ;; esac
      if ! grep -q -x "$line $id" "$used"; then
        echo "stale deviation: tests/basis/deviations.txt:$line ($cglob | $lglob) matches no failure of $id"
        status=1
      fi
    done
  done < "$dev"
fi

{
  echo
  echo "## Explained deviations"
  echo
  echo "| Configuration | Check | Category | Reason |"
  echo "|---|---|---|---|"
  sort "$xfails" | sed 's/|/ | /g; s/^/| /; s/$/ |/'
  echo
  echo "## Unexplained failures"
  echo
  sed 's/^/    /' "$unexplained"
  echo
  echo "## Files of lib/basis that a host does not load (xc1)"
  echo
  echo "| Configuration | File | First error |"
  echo "|---|---|---|"
  for id in $ids; do
    d=$out/$(dirname_of "$id")
    [ -s "$d/basis.dropped" ] || continue
    sed -e "s|$out/[^/]*/basis/basis/||g" -e 's/|/\\|/g' "$d/basis.dropped" |
      awk -F '\t' -v id="$id" '{ print "| " id " | " $1 " | " $2 " |" }'
  done
} >> "$report"
echo "report: ${report#"$root"/}"
exit $status
