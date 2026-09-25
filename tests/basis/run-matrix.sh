#!/bin/sh
# Run the Basis Library suite (tests/basis/*.sml) on a matrix of configurations.
#   tests/basis/run-matrix.sh [-j N] [--configs C1,C2,...] [FILTER]
#   tests/basis/run-matrix.sh --perf [--configs C1,C2,...] [FILTER]
#
# Configurations (default: rune):
#   rune                   bin/rune, the self-hosted compiler, + bin/runevm
#                          (override: RUNE=, RUNEVM=; both must be absolute)
#   rune:windows  rune:windows32
#   rune:linux32  rune:ppc64   the same on a VM of another machine: a 32-bit
#                          x86, and a big-endian 64-bit PowerPC under qemu
#                          (make portability; RUNEVM_LINUX32=, RUNEVM_PPC64=)
#                          bin/rune + bin/runevm.exe or bin/runevm32.exe, the
#                          VMs of make windows (RUNEVM_WINDOWS=,
#                          RUNEVM_WINDOWS32=); a program runs in a directory
#                          on the Windows side (tests/windows-dir.sh), and
#                          needs Windows, or WSL, which starts an .exe
#   rune:opt               bin/rune, and every program translated to native
#                          code by runeopt and run so: bin/runevm-opt
#                          (RUNEVM_OPT=; docs/native.md)
#   rune:new               bin/rune making the register bytecode of vm/new
#                          (bin/rune-new, RUNE_NEW=) and vm/new's first loop
#                          running it (bin/runevm-new, RUNEVM_NEW=;
#                          docs/plans/middle-end.md, M5)
#   windows                rune:windows and rune:windows32
#   portability            rune:linux32 and rune:ppc64
#   native:mlton  native:smlnj  native:smlnj32  native:polyml
#                          the suite against the host's own Basis Library
#   xc1:mlton  xc1:smlnj  xc1:smlnj32  xc1:polyml
#                          the suite against Rune's Basis Library (lib/basis)
#                          compiled by the host; see below
#   hosts                  native:HOST for the four hosts
#   xc1                    xc1:HOST for the four hosts
#   all                    rune, hosts and xc1 (not windows)
# The hosts are the releases scripts/fetch-hosts.sh installed under
# ${RUNE_HOSTS:-$HOME/.local/rune-hosts} (`make hosts`): MLton, SML/NJ built
# for 64 bits (smlnj) and for 32 (smlnj32: 31-bit int and word) and Poly/ML;
# MLTON=, SMLNJ=, SMLNJ32= and POLY= override their commands. A configuration
# is reported under an id that carries the version of the host, e.g.
# native:smlnj32@110.99.9; tests/basis/deviations.txt matches on it.
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
# the same failure in an xc1 configuration, which shares the library source,
# and in a rune:windows one, which shares the library and the compiler.
# Exit status 1: an unexplained failure, or a line that matches no failure of
# a configuration it names (so the file never goes stale; not checked when a
# FILTER is given, nor, in a configuration where a test timed out, for a line
# that matches one of the test's checks as the rune configuration reports
# them: those after the point where it stopped did not run). A test that is
# ABSENT for the rune configuration is the
# failed check @absent/TEST, to be explained likewise: Rune's library is
# meant to be complete.
#
# Timing: every program's time is kept, and the run ends with where the time
# went: the phases, each configuration and host, the slowest programs, and
# how busy the -j N job slots were. The times of a run are the schedule of the
# next: the (configuration, test) pairs start longest first, so that a slow
# one does not run alone at the end ($out/timings.tsv; a pair not timed yet
# counts as long). An xc1 configuration first finds the files of lib/basis
# its host loads (the probe, a job of its own that runs first); its result is
# kept for as long as lib/basis, the shim and the host stay the same.
#
# A test that does not load whole is cut down by halving its sections, and
# each try compiles the library again: on a host that is most of what a run
# costs. What the halving finds depends on the library, the tools and the test
# and on nothing else, so it is kept in $out/CONFIG/TEST.sections against a
# checksum of those (of the compiler too for the rune configuration), and a
# later run goes straight to the sections that load. --refresh looks again.
#
# A host that keeps a session -- SML/NJ and Poly/ML -- gets a heap image with
# the library in it once the probe has found which of its files load, so that
# a program uses only its own sources: that is what most of a run costs there.
# RUNE_MATRIX_NO_IMAGE=1 turns it off.
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
refresh=${RUNE_MATRIX_REFRESH:-0}
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
    --refresh) refresh=1; shift ;;
    -*) echo "usage: tests/basis/run-matrix.sh [-j N] [--perf] [--refresh] [--configs C1,C2,...] [FILTER]" >&2; exit 2 ;;
    *) filter=$1; shift ;;
  esac
done

self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
# Every program runs in the same time zone, whatever the machine's: a rule of
# POSIX that the C library reads without a time zone database, 3:30 west of
# UTC with summer time from the second Sunday in March to the first Sunday in
# November. Local time then differs from UTC by a fraction of an hour and by
# the season, so that the checks of local time can tell them apart, and what
# a host gets wrong about local time is the same on every machine.
TZ='NST3:30NDT,M3.2.0,M11.1.0'
export TZ
# A program of Windows started from WSL sees a variable only if WSLENV names it.
case ":${WSLENV:-}:" in *:TZ:*) ;; *) WSLENV="TZ${WSLENV:+:$WSLENV}"; export WSLENV ;; esac
cd "$(dirname "$0")/../.."
root=$(pwd)
suite=$root/tests/basis
out=$root/tests/out/matrix
limit=${RUNE_MATRIX_TIMEOUT:-120}
mkdir -p "$out"
# Files of this invocation (several may run at once, on different tests).
run=${RUNE_MATRIX_RUN:-$out/run.$$}

dirname_of() { echo "$1" | tr ':@/' '---'; }

# now: seconds since the epoch, with the nanoseconds where date has them.
case $(date +%N) in
  *N*) now() { date +%s; } ;;
  *) now() { date +%s.%N; } ;;
esac
# since START [END]: seconds from START to END (default: now), 3 decimals.
since() { awk -v a="$1" -v b="${2:-$(now)}" 'BEGIN { printf "%.3f", b - a }'; }

# ------------------------------------------------------------------ worker
# The table $out/configs maps an id to "kind host command...".
config_field() { awk -F '\t' -v id="$1" -v n="$2" '$1 == id { print $n }' "$run/configs"; }

# first_error FILE...: the line that best explains why a program did not load
# (not a declaration that an interactive system echoes, like `val file_error`).
first_error() {
  cat "$@" 2> /dev/null | grep -v -E '^PASS |^\[opening |^[[:space:]]*(val|exception|type|eqtype|datatype|structure|signature|functor) ' |
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
# fresh_bytecode LOADDIR SOURCE...: with RUNE_MATRIX_BYTECODE, the directory
# of a run of the `rune` configuration (make test-native gives it that of
# test-basis), whether the program it compiled there can be taken instead of
# compiling it again: it was compiled from the same sources (program_key),
# and it is newer than the compiler, the sources and every file of lib/basis. The configurations that compile with
# bin/rune and run the bytecode elsewhere (rune:opt) compile the same file.
fresh_bytecode() {
  [ -n "${RUNE_MATRIX_BYTECODE:-}" ] || return 1
  reused=$RUNE_MATRIX_BYTECODE/${1##*/}/prog.rbc
  shift
  [ -f "$reused" ] && [ -f "${reused%.rbc}.key" ] || return 1
  [ "$(program_key "$@")" = "$(cat "${reused%.rbc}.key")" ] || return 1
  [ "$(readlink -f "$cmd1")" -nt "$reused" ] && return 1
  for src in "$@"; do [ "$src" -nt "$reused" ] && return 1; done
  [ -z "$(find "$root/lib/basis" -newer "$reused" -print | head -1)" ]
}

# program_key SOURCE...: what a program is compiled from, the names and
# the contents of its sources, as a line.
program_key() {
  printf '%s ' "$@"
  cat "$@" | cksum
}

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
      if fresh_bytecode "$loaddir" "$@"; then
        cp "$RUNE_MATRIX_BYTECODE/${loaddir##*/}/prog.rbc" "$loaddir/prog.rbc"
      else
        "$cmd1" "$@" -o "$loaddir/prog.rbc" > "$loaddir/log" 2>&1 || return 1
      fi
      program_key "$@" > "$loaddir/prog.key"
      case $host in
        windows*)
          # in the same place on the Windows side, with the program beside it.
          # timeout kills the process WSL starts for the .exe, and the
          # program of Windows behind it dies with that one.
          windows_dir=$RUNE_WINDOWS_DIR/matrix/${loaddir#"$out"/}
          rm -rf "$windows_dir"
          mkdir -p "$windows_dir"
          cp "$loaddir/prog.rbc" "$windows_dir/prog.rbc"
          (cd "$windows_dir" && timeout "$limit" "$cmd2" prog.rbc > "$loaddir/stdout" 2>> "$loaddir/log" < /dev/null)
          ;;
        *) (cd "$loaddir" && timeout "$limit" "$cmd2" prog.rbc > stdout 2>> log < /dev/null) ;;
      esac
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
    *:smlnj|*:smlnj32)
      # With a heap image of the library the program starts from it and uses
      # only its own files; the image itself uses what it is given.
      if [ "$kind" = xc1 ] && [ -f "$cfgout/basis.image" ]; then
        prefix_count=$(prefix | wc -w)
        if [ "$prefix_count" -gt "$#" ]; then
          echo "error: saved basis image has $prefix_count prefix files, but load received only $# source files" >> "$loaddir/log"
          return 1
        fi
        shift "$prefix_count"
        write_driver "$loaddir/driver.sml" "$@"
        (cd "$loaddir" && timeout "$limit" "$cmd1" "@SMLload=$cfgout/basis.heap" > stdout 2> log < /dev/null)
      else
        write_driver "$loaddir/driver.sml" "$@"
        (cd "$loaddir" && timeout "$limit" "$cmd1" driver.sml > stdout 2> log < /dev/null)
      fi
      ;;
    *:polyml)
      if [ "$kind" = xc1 ] && [ -f "$cfgout/basis.image" ]; then
        prefix_count=$(prefix | wc -w)
        if [ "$prefix_count" -gt "$#" ]; then
          echo "error: saved basis image has $prefix_count prefix files, but load received only $# source files" >> "$loaddir/log"
          return 1
        fi
        shift "$prefix_count"
        write_driver "$loaddir/driver.sml" "$@"
        sed -i "1i val () = PolyML.SaveState.loadState \"$cfgout/basis.state\";" "$loaddir/driver.sml"
      else
        write_driver "$loaddir/driver.sml" "$@"
      fi
      (cd "$loaddir" && timeout "$limit" "$cmd1" -q --error-exit --use driver.sml > stdout 2> log < /dev/null)
      ;;
    *) echo "unknown configuration kind $kind:$host" > "$loaddir/log"; return 1 ;;
  esac
  status=$?
  [ $status = 124 ] && echo "timed out after $limit s" >> "$loaddir/log"
  grep -q '^SUMMARY ' "$loaddir/stdout"
}

# prefix: the files a program of the configuration starts with. For MLton,
# which compiles a program whole and keeps no session, that is only the part
# of the library the program loads: `rune --basis-deps` says which, and a
# test of List compiles 49 files of the 241 instead of all of them. $needed
# holds them when it could be worked out, and is cleared to fall back.
prefix() {
  [ "$kind" = xc1 ] || return 0
  cat "$cfgout/basis/prelude"
  if [ -n "${needed:-}" ]; then printf '%s\n' "$needed"; else cat "$cfgout/basis.loaded"; fi
}

# set_needed: the part of the configuration's library this test loads.
set_needed() {
  needed=""
  [ "$kind" = xc1 ] && [ "$host" = mlton ] || return 0
  [ "${RUNE_MATRIX_NO_SUBSET:-0}" = 0 ] || return 0
  runebin=${RUNE:-$root/bin/rune}
  [ -x "$runebin" ] || return 0
  deps=$cfgout/$test.deps
  # shellcheck disable=SC2086
  if ! "$runebin" --basis-deps "$suite/harness.sml" $(for u in $uses; do echo "$suite/$u"; done) \
         "$src" "$suite/finish.sml" > "$deps" 2>/dev/null; then
    rm -f "$deps"; return 0
  fi
  needed=$(awk 'NR == FNR { want[$0] = 1; next }
                { n = $0; sub(/.*\//, "", n); if (n in want) print }' "$deps" "$cfgout/basis.loaded")
  rm -f "$deps"
  [ -n "$needed" ] || needed=""
  return 0
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

# run_one CONFIG TEST: the result of TEST in CONFIG, and in TEST.time how
# long it took: "total first wait", the program as it is, and waiting for the
# probe of an xc1 configuration (the rest of total is the fallback: probing
# structures and trying sections).
run_one() {
  t_start=$(now)
  t_wait=0
  t_first=""
  run_one_body "$@"
  t_end=$(now)
  printf '%s %s %s\n' "$(since "$t_start" "$t_end")" "$(since "$t_start" "${t_first:-$t_end}")" "$t_wait" > "$cfgout/$test.time"
}

run_one_body() {
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
    # the probe of the configuration's library runs as a job of its own
    t_w=$(now)
    while [ ! -f "$cfgout/basis.done" ]; do sleep 1; done
    t_wait=$(since "$t_w")
    t_start=$(awk -v a="$t_start" -v w="$t_wait" 'BEGIN { printf "%.3f", a + w }')
    if [ "$(cat "$cfgout/basis.done")" != ok ]; then
      echo "FAIL @load/$test -- $(cat "$cfgout/basis.done")" > "$result"
      return
    fi
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
  # What the halving below finds depends on the library, the tools and the
  # test, so it is kept: looking again costs a compilation of the library per
  # group, which is most of what a run spends on a host.
  toolkey=$libkey
  [ "$kind" = rune ] && toolkey="$libkey.$runekey"
  seckey="$toolkey-$(cksum < "$src" | cut -d " " -f 1)-$(echo "$cmd1 $cmd2 $limit" | cksum | cut -d " " -f 1)"
  kept=$cfgout/$test.sections
  if [ "$refresh" = 0 ] && [ -f "$kept" ] && [ "$(head -1 "$kept")" = "$seckey" ]; then
    set_needed
    keep=$(sed -n '2p' "$kept")
    if [ "$keep" = "@all" ]; then
      final=$src
    else
      tail -n +3 "$kept" >> "$result.tmp"
      final=$cfgout/$test.final.sml
      variant "$src" "$final" "$keep"
    fi
    # shellcheck disable=SC2046
    if load "$work" run $(sources "$final"); then
      t_first=$(now)
      grep -E '^(PASS|FAIL) ' "$work/stdout" >> "$result.tmp"
      claimed=$(sed -n 's/^SUMMARY \([0-9]*\) checks.*/\1/p' "$work/stdout")
      counted=$(grep -c -E '^(PASS|FAIL) ' "$work/stdout")
      [ "$claimed" = "$counted" ] ||
        echo "FAIL @load/$test -- SUMMARY reports $claimed checks but $counted were printed" >> "$result.tmp"
      mv "$result.tmp" "$result"
      return
    fi
    # what was kept no longer holds: look again
    : > "$result.tmp"
    rm -f "$kept"
    needed=""
    final=$src
  fi
  set_needed
  # shellcheck disable=SC2046
  load "$work" run $(sources "$src")
  loaded=$?
  if [ $loaded != 0 ] && [ -n "$needed" ]; then
    # the part of the library it seemed to need was not enough: try it whole
    needed=""
    # shellcheck disable=SC2046
    load "$work" run $(sources "$src")
    loaded=$?
  fi
  t_first=$(now)
  if [ $loaded != 0 ]; then
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
        # The sections that do not load, by halving: a set of sections that
        # loads has none of them in it, so only a half that fails is looked
        # into, and the host runs once per group instead of once per section.
        # (A section that does not load does not load in any set that holds
        # it, so the outcome is that of trying them one by one.)
        keep=""
        stack=$cfgout/$test.groups
        count=$(echo $sections | wc -w)
        if [ "$count" = 1 ]; then printf '%s\n' "$sections" > "$stack"
        else
          half=$((count / 2))
          { echo $sections | cut -d " " -f "1-$half"; echo $sections | cut -d " " -f "$((half + 1))-"; } > "$stack"
        fi
        while [ -s "$stack" ]; do
          group=$(head -1 "$stack")
          tail -n +2 "$stack" > "$stack.rest"; mv "$stack.rest" "$stack"
          [ -n "$group" ] || continue
          variant "$src" "$cfgout/$test.try.sml" "$group"
          # shellcheck disable=SC2046
          if load "$work" check $(sources "$cfgout/$test.try.sml"); then
            keep="$keep $group"
            continue
          fi
          n=$(echo $group | wc -w)
          if [ "$n" = 1 ]; then
            echo "FAIL @section/$test/$group -- $(first_error "$work/log" "$work/stdout")" >> "$result.tmp"
            continue
          fi
          half=$((n / 2))
          { echo $group | cut -d " " -f "1-$half"; echo $group | cut -d " " -f "$((half + 1))-"; cat "$stack"; } > "$stack.new"
          mv "$stack.new" "$stack"
        done
        rm -f "$stack"
        { printf '%s\n%s\n' "$seckey" "$keep"; grep '^FAIL @section/' "$result.tmp" || true; } > "$kept"
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

  # a program that loaded whole has nothing to leave out next time
  [ "$loaded" = 0 ] && printf '%s\n@all\n' "$seckey" > "$kept"
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
    # a structure the program names, or one the timing wrapper itself needs
    for m in $(cut -f 1 "$cfgout/basis.dropped" | while read -r f; do awk -F '\t' -v f="$f" '{ n = split($1, p, "/"); if (p[n] == f) print $2 }' "$cfgout/basis/files"; done); do
      if grep -q -w "$m" "$root/tests/perf/$test.sml"; then echo "NA $m" > "$result"; return; fi
      case "$m" in Timer|Time|LargeInt) echo "NA $m (the wrapper that times the program needs it)" > "$result"; return ;; esac
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

# session_probe ID PRELUDE FILES: use the files one after another in one
# session of the host, and set `accepted` to those that loaded (and write the
# others to basis.dropped) when the result loads as a program. The files a
# host rejects are few, so this replaces one run of the host per file.
session_probe() {
  probedir=$cfgout/basis.probe
  rm -rf "$probedir"
  mkdir -p "$probedir"
  # The prelude hides the top-level values of the host (print, ^, exnMessage
  # among them) and the files rebind TextIO, so the session keeps what it
  # needs of the host's library before it starts.
  {
    for f in $2; do printf 'val () = use "%s";\n' "$f"; done
    # flushed, so that a marker and the errors of the host stay in order
    printf 'val probeSay__ = fn s__ => (TextIO.print s__; TextIO.flushOut TextIO.stdOut);\n'
    printf 'val probeWhy__ = General.exnMessage;\n'
    for f in $3; do
      printf 'val () = probeSay__ "@@FILE %s\\n";\n' "$f"
      printf 'val () = (use "%s"; probeSay__ "@@OK\\n") handle probe__ => probeSay__ (String.concat ["@@DROP ", probeWhy__ probe__, "\\n"]);\n' "$f"
    done
    printf 'val () = probeSay__ "@@END\\n";\n'
  } > "$probedir/probe.sml"
  case "$host" in
    polyml) (cd "$probedir" && timeout $((limit * 8)) "$cmd1" -q --use probe.sml > out 2>&1 < /dev/null) ;;
    *) (cd "$probedir" && timeout $((limit * 8)) "$cmd1" probe.sml > out 2>&1 < /dev/null) ;;
  esac
  grep -q '^@@END' "$probedir/out" || return 1
  # the files that loaded, and the first error of each of the others
  awk '
    /^@@FILE / { file = $2; seg = ""; next }
    /^@@OK/ { if (file != "") print "OK	" file; file = ""; next }
    /^@@DROP / { if (file != "") { why = seg; if (why == "") why = substr($0, 8); print "DROP	" file "	" why } file = ""; next }
    { if (file != "" && seg == "" && $0 ~ /[Ee]rror|xception|raised/ && $0 !~ /^\[opening /) seg = substr($0, 1, 300) }
  ' "$probedir/out" > "$probedir/verdicts"
  accepted=$(awk -F '\t' '$1 == "OK" { printf "%s ", $2 }' "$probedir/verdicts")
  awk -F '\t' -v out="$cfgout/basis.dropped" '$1 == "DROP" { n = split($2, p, "/"); printf "%s\t%s\n", p[n], $3 >> out }' "$probedir/verdicts"
  # make sure of it: the accepted files must load as one program
  # shellcheck disable=SC2086
  if load "$cfgout/basis.work" check $2 $accepted "$gen/ok.sml"; then
    rm -rf "$probedir"
    return 0
  fi
  accepted=""
  rm -rf "$probedir"
  return 1
}

# libkey: the checksum of everything that decides a test's sections apart
# from the test and the tools, computed once for the run.
libkey=${RUNE_MATRIX_LIBKEY:-}
if [ -z "$libkey" ]; then
  libkey=$(cat lib/basis/MANIFEST lib/basis/*.sml tests/basis/host/* vm/prims.def 2>/dev/null |
           cksum | cut -d " " -f 1)
fi
export RUNE_MATRIX_LIBKEY=$libkey
# The compiler decides the sections of the rune configuration and nothing of a
# host's, whose version is in the name of its output directory already.
runekey=${RUNE_MATRIX_RUNEKEY:-}
if [ -z "$runekey" ]; then
  runekey=$(cat src/*/*.sml vm/*.c vm/*.h 2>/dev/null | cksum | cut -d " " -f 1)
fi
export RUNE_MATRIX_RUNEKEY=$runekey

# discard_image: remove a saved host session and the marker that makes load
# use it. The image is valid only while basis.key matches the current library.
discard_image() {
  rm -f "$cfgout/basis.image" "$cfgout/basis.heap".* "$cfgout/basis.state"
}

# save_image PRELUDE FILES: for a host that keeps a session, a heap image
# with the library already in it, so that a program does not use its sources
# again -- which is most of what a run of the matrix costs on such a host.
# SML/NJ exports one that uses the files it is given when it resumes; Poly/ML
# saves a state that a program loads first. basis.image says there is one.
save_image() {
  discard_image
  [ "${RUNE_MATRIX_NO_IMAGE:-0}" = 0 ] || return 0
  case "$host" in
    smlnj|smlnj32)
      { printf 'val () = ('
        sep=""
        for f in $1 $2; do printf '%suse "%s"' "$sep" "$f"; sep="; "; done
        printf ');\n'
        printf 'val resumed__ = SMLofNJ.exportML "%s";\n' "$cfgout/basis.heap"
        # The program is driver.sml of the directory the test runs in and
        # not an argument: CommandLine.arguments is one of the things the
        # suite checks, and it must be empty under the runner.
        printf 'val () =\n'
        printf '  if resumed__ then\n'
        printf '    ((use "driver.sml"\n'
        printf '        handle e => (print ("uncaught exception " ^ exnName e ^ " [" ^ exnMessage e ^ "]\\n");\n'
        printf '                     OS.Process.exit OS.Process.failure));\n'
        printf '     OS.Process.exit OS.Process.success)\n'
        printf '  else OS.Process.exit OS.Process.success;\n'
      } > "$cfgout/basis.export.sml"
      if timeout $((limit * 8)) "$cmd1" "$cfgout/basis.export.sml" > "$cfgout/basis.export.log" 2>&1 &&
         ls "$cfgout/basis.heap".* > /dev/null 2>&1; then
        echo ok > "$cfgout/basis.image"
      fi
      ;;
    polyml)
      { printf 'val () = ('
        sep=""
        for f in $1 $2; do printf '%suse "%s"' "$sep" "$f"; sep="; "; done
        printf ');\n'
        printf 'val () = PolyML.SaveState.saveState "%s";\n' "$cfgout/basis.state"
        printf 'val () = OS.Process.exit OS.Process.success;\n'
      } > "$cfgout/basis.export.sml"
      if timeout $((limit * 8)) "$cmd1" -q --error-exit --use "$cfgout/basis.export.sml" \
           > "$cfgout/basis.export.log" 2>&1 < /dev/null && [ -f "$cfgout/basis.state" ]; then
        echo ok > "$cfgout/basis.image"
      fi
      ;;
  esac
  return 0
}

# probe_basis ID: generate the library sources of xc1 configuration ID and
# find the files of lib/basis that load on its host, in
#   basis.loaded    their paths, in load order
#   basis.provides  the structures they declare
#   basis.dropped   "FILE<TAB>first error" for the others
# and write basis.done: "ok", or why the library cannot be used. The result
# is kept while its key, a checksum of what decides it, stays the same.
probe_basis() {
  kind=xc1
  host=$(config_field "$1" 3)
  cmd1=$(config_field "$1" 4)
  cfgout=$out/$(dirname_of "$1")
  mkdir -p "$cfgout"
  # A shell error in a probe must release the test jobs waiting below. In
  # particular, dash exits the whole worker when shift is given too large a
  # count; without this marker every job slot can wait for ever.
  probe_status=0
  trap 'probe_status=$?; if [ ! -f "$cfgout/basis.done" ]; then printf "probe exited before completion (status %s)\n" "$probe_status" > "$cfgout/basis.done"; fi' 0
  trap 'exit 1' HUP INT TERM
  t_probe=$(now)
  key=$(cat lib/basis/MANIFEST lib/basis/*.sml tests/basis/host/* vm/prims.def | cksum | cut -d ' ' -f 1)-$(echo "$cmd1" | cksum | cut -d ' ' -f 1)
  if [ -f "$cfgout/basis.key" ] && [ "$(cat "$cfgout/basis.key")" = "$key" ] && [ -f "$cfgout/basis.loaded" ] &&
     [ -d "$cfgout/basis" ]; then
    echo "cached 0 $(since "$t_probe")" > "$cfgout/basis.time"
    echo ok > "$cfgout/basis.done"
    if [ ! -f "$cfgout/basis.image" ]; then
      save_image "$(cat "$cfgout/basis/prelude")" "$(cat "$cfgout/basis.loaded")"
    fi
    return
  fi
  # basis.loaded and the saved session describe the library named by
  # basis.key. Do not let load mistake either for the library being probed
  # after a source or host change.
  rm -f "$cfgout/basis.done" "$cfgout/basis.key" "$cfgout/basis.loaded" \
        "$cfgout/basis.provides" "$cfgout/basis.dropped" "$cfgout/basis.time"
  discard_image
  gen=$cfgout/basis
  rm -rf "$gen"
  if ! sh tests/basis/host/gen-host-basis.sh "$gen"; then
    echo "tests/basis/host/gen-host-basis.sh failed" > "$cfgout/basis.done"
    return
  fi
  printf '%s\n' 'val () = TextIO.print "SUMMARY loaded\n"' > "$gen/ok.sml"
  prelude=$(cat "$gen/prelude")
  # shellcheck disable=SC2086
  if ! load "$cfgout/basis.work" check $prelude "$gen/ok.sml"; then
    echo "tests/basis/host/rune-prim.sml does not load: $(first_error "$cfgout/basis.work/log" "$cfgout/basis.work/stdout")" > "$cfgout/basis.done"
    echo "run-matrix: $1: $(cat "$cfgout/basis.done")" >&2
    return
  fi
  all=$(cut -f 1 "$gen/files")
  : > "$cfgout/basis.dropped"
  tried=1
  # shellcheck disable=SC2086
  if load "$cfgout/basis.work" check $prelude $all "$gen/ok.sml"; then
    accepted=$all
  else
    # SML/NJ and Poly/ML can use one file after another in one session, which
    # finds the files that do not load in one run of the host instead of one
    # per file; the set it finds is then loaded as a program to make sure of
    # it, and only if that fails does every file get its own run.
    accepted=""
    case "$host" in
      smlnj|smlnj32|polyml) session_probe "$1" "$prelude" "$all" && tried=2 ;;
    esac
    if [ -z "$accepted" ]; then
      : > "$cfgout/basis.dropped"
      # (load and its helpers use f: sh has no local variables)
      for candidate in $all; do
        tried=$((tried + 1))
        # shellcheck disable=SC2086
        if load "$cfgout/basis.work" check $prelude $accepted "$candidate" "$gen/ok.sml"; then
          accepted="$accepted $candidate"
        else
          printf '%s\t%s\n' "$(basename "$candidate")" "$(first_error "$cfgout/basis.work/log" "$cfgout/basis.work/stdout")" >> "$cfgout/basis.dropped"
        fi
      done
    fi
  fi
  : > "$cfgout/basis.loaded"
  : > "$cfgout/basis.provides"
  for f in $accepted; do
    echo "$f" >> "$cfgout/basis.loaded"
    awk -F '\t' -v f="$f" '$1 == f { n = split($2, m, " "); for (i = 1; i <= n; i++) print m[i] }' "$gen/files" >> "$cfgout/basis.provides"
  done
  rm -rf "$cfgout/basis.work"
  save_image "$prelude" "$accepted"
  echo "probed $tried $(since "$t_probe")" > "$cfgout/basis.time"
  echo "$key" > "$cfgout/basis.key"
  echo ok > "$cfgout/basis.done"
}

if [ -n "$one_config" ]; then
  if [ "$perf" = 1 ]; then perf_one "$one_config" "$one_test"
  elif [ "$one_test" = @probe ]; then probe_basis "$one_config"
  else run_one "$one_config" "$one_test"
  fi
  exit 0
fi

# ------------------------------------------------------------------ configurations
hosts_prefix=${RUNE_HOSTS:-$HOME/.local/rune-hosts}

expand() {
  for c in $(echo "$1" | tr ',' ' '); do
    case "$c" in
      hosts) echo native:mlton native:smlnj native:smlnj32 native:polyml ;;
      xc1) echo xc1:mlton xc1:smlnj xc1:smlnj32 xc1:polyml ;;
      all) echo rune; expand hosts,xc1 ;;
      windows) echo rune:windows rune:windows32 ;;
      portability) echo rune:linux32 rune:ppc64 ;;
      *) echo "$c" ;;
    esac
  done
}

# resolve CONFIG: append "id kind host cmd1 cmd2" to $out/configs.
resolve() {
  spec=$1
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
    rune:windows|rune:windows32)
      cmd1=${RUNE:-$root/bin/rune}
      if [ "$host" = windows ]; then cmd2=${RUNEVM_WINDOWS:-$root/bin/runevm.exe}
      else cmd2=${RUNEVM_WINDOWS32:-$root/bin/runevm32.exe}
      fi
      id=rune:$host
      [ -x "$cmd1" ] && [ -x "$cmd2" ] || { echo "run-matrix: $cmd1 or $cmd2 is missing (run make windows)" >&2; return 1; }
      "$cmd2" --version > /dev/null 2>&1 || { echo "run-matrix: $cmd2 will not start here; Windows or WSL is needed" >&2; return 1; }
      if [ -z "${RUNE_WINDOWS_DIR:-}" ]; then
        RUNE_WINDOWS_DIR=$(sh "$root/tests/windows-dir.sh") || { echo "run-matrix: no directory on the Windows side; set RUNE_WINDOWS_DIR" >&2; return 1; }
        export RUNE_WINDOWS_DIR
      fi
      ;;
    rune:opt)
      # The library and the compiler of the `rune` configuration, and every
      # program run as native code: bin/runevm-opt translates the bytecode
      # with runeopt and runs the executable (docs/native.md, Tests).
      cmd1=${RUNE:-$root/bin/rune}
      cmd2=${RUNEVM_OPT:-$root/bin/runevm-opt}
      id=rune:opt
      [ -x "$cmd1" ] && [ -x "$cmd2" ] || { echo "run-matrix: $cmd1 or $cmd2 is missing (run make bin/runevm-opt)" >&2; return 1; }
      ;;
    rune:new)
      # The library of the `rune` configuration, compiled to the register
      # bytecode, and every program run by vm/new's first loop.
      cmd1=${RUNE_NEW:-$root/bin/rune-new}
      cmd2=${RUNEVM_NEW:-$root/bin/runevm-new}
      id=rune:new
      [ -x "$cmd1" ] && [ -x "$cmd2" ] || { echo "run-matrix: $cmd1 or $cmd2 is missing (run make bin/rune-new bin/runevm-new)" >&2; return 1; }
      ;;
    rune:linux32|rune:ppc64)
      # The library and the compiler of the `rune` configuration on a VM of
      # another machine (make portability): a 32-bit x86, and a big-endian
      # 64-bit PowerPC, which its own wrapper runs under qemu. Nothing of the
      # suite differs -- the bytecode is the same file -- so what is tested is
      # the VM.
      cmd1=${RUNE:-$root/bin/rune}
      if [ "$host" = linux32 ]; then cmd2=${RUNEVM_LINUX32:-$root/bin/runevm32}
      else cmd2=${RUNEVM_PPC64:-$root/bin/runevm-ppc64}
      fi
      id=rune:$host
      [ -x "$cmd1" ] && [ -x "$cmd2" ] || { echo "run-matrix: $cmd1 or $cmd2 is missing (run make portability)" >&2; return 1; }
      "$cmd2" --version > /dev/null 2>&1 || { echo "run-matrix: $cmd2 will not start here" >&2; return 1; }
      ;;
    native:mlton|xc1:mlton)
      cmd1=${MLTON:-$hosts_prefix/mlton/bin/mlton}
      version=$("$cmd1" 2> /dev/null | sed -n '1s/^MLton \([0-9][0-9.]*\).*/\1/p')
      ;;
    native:smlnj|xc1:smlnj)
      cmd1=${SMLNJ:-$hosts_prefix/smlnj/bin/sml}
      version=$("$cmd1" @SMLversion 2> /dev/null | sed -n '1s/^sml \([0-9][0-9.]*\).*/\1/p')
      ;;
    native:smlnj32|xc1:smlnj32)
      cmd1=${SMLNJ32:-$hosts_prefix/smlnj32/bin/sml}
      version=$("$cmd1" @SMLversion 2> /dev/null | sed -n '1s/^sml \([0-9][0-9.]*\).*/\1/p')
      ;;
    native:polyml|xc1:polyml)
      cmd1=${POLY:-$hosts_prefix/polyml/bin/poly}
      version=$("$cmd1" -v 2> /dev/null | sed -n '1s/^Poly\/ML \([0-9][0-9.]*\).*/\1/p')
      ;;
    *) echo "run-matrix: unknown configuration '$1'" >&2; return 1 ;;
  esac
  if [ "$kind" != rune ]; then
    if [ -z "$version" ]; then
      echo "run-matrix: cannot run $cmd1 for configuration '$1' (make hosts installs the hosts)" >&2
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
    rune|rune:*|xc1:*) rm -rf "$d/probe" ;;
    *) [ -n "$filter" ] || rm -rf "$d/probe" ;;
  esac
done

# The probes of the xc1 configurations. In a --perf run they come first;
# otherwise they are jobs of the run itself.
t_run=$(now)
for id in $ids; do
  case "$id" in xc1:*) rm -f "$out/$(dirname_of "$id")/basis.done" ;; esac
done
if [ "$perf" = 1 ]; then
  pids=""
  for id in $ids; do
    case "$id" in xc1:*) probe_basis "$id" & pids="$pids $!" ;; esac
  done
  for pid in $pids; do wait "$pid"; done
  for id in $ids; do
    case "$id" in
      xc1:*) [ "$(cat "$out/$(dirname_of "$id")/basis.done")" = ok ] || { echo "run-matrix: $id: $(cat "$out/$(dirname_of "$id")/basis.done")" >&2; exit 2; } ;;
    esac
  done
fi
if [ "$perf" = 1 ]; then
  # One at a time: a timing is only worth something on an idle machine.
  for id in $ids; do for t in $tests; do printf '%s\n%s\n' "$id" "$t"; done; done |
    RUNE_MATRIX_RUN=$run RUNE_MATRIX_PERF=1 RUNE_MATRIX_REFRESH=$refresh xargs -n 2 -P 1 sh "$self" --one
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
# The queue: the probes, then the pairs longest first by the times of earlier
# runs (a pair without one first of all, as it may be long).
timings=$out/timings.tsv
tab=$(printf '\t')
{
  for id in $ids; do case "$id" in xc1:*) printf '%s\t@probe\t1e12\n' "$id" ;; esac; done
  for id in $ids; do for t in $tests; do printf '%s\t%s\n' "$id" "$t"; done; done |
    awk -F '\t' -v tf="$timings" '
      BEGIN { while ((getline l < tf) > 0) { split(l, f, "\t"); d[f[1] "\t" f[2]] = f[3] } }
      { k = $1 "\t" $2; printf "%s\t%s\t%s\n", $1, $2, (k in d) ? d[k] : 1e9 }'
} | sort -t "$tab" -k3,3gr -s | cut -f 1,2 | tr '\t' '\n' |
  RUNE_MATRIX_RUN=$run RUNE_MATRIX_REFRESH=$refresh xargs -n 2 -P "$jobs" sh "$self" --one
t_tests=$(since "$t_run")

# ------------------------------------------------------------------ report
# One awk program reads the deviations and every result: which failures a
# line explains, the table of the report, the summary per configuration, the
# stale lines, and the timings.
t_report=$(now)
report=$out/report${filter:+-$filter}.md
printf '%s\n' $ids > "$run/ids"
printf '%s\n' $tests > "$run/tests"
# the files of lib/basis a host did not load (xc1)
for id in $ids; do
  d=$out/$(dirname_of "$id")
  [ -s "$d/basis.dropped" ] || continue
  sed -e "s|$out/[^/]*/basis/basis/||g" -e 's/|/\\|/g' "$d/basis.dropped" |
    awk -F '\t' -v id="$id" '{ print "| " id " | " $1 " | " $2 " |" }'
done > "$run/dropped"
for id in $ids; do
  printf '%s\t%s\n' "$id" "$out/$(dirname_of "$id")"
done > "$run/dirs"
[ -f "$suite/deviations.txt" ] || : > "$suite/deviations.txt"
[ -f "$timings" ] || : > "$timings"
awk -v devfile="$suite/deviations.txt" -v idsfile="$run/ids" -v testsfile="$run/tests" \
    -v dirsfile="$run/dirs" -v report="$report" -v droppedfile="$run/dropped" \
    -v filter="$filter" -v jobs="$jobs" -v wall="$t_tests" -v timings="$timings" \
    -v newtimings="$run/timings.new" -v unexplainedfile="$run/unexplained" -v statsfile="$run/stats" '
function g2re(g,   i, n, c, r, inb) {
  r = "^"; n = length(g); inb = 0
  for (i = 1; i <= n; i++) {
    c = substr(g, i, 1)
    if (inb) { r = r c; if (c == "]") inb = 0; continue }
    if (c == "*") r = r ".*"
    else if (c == "?") r = r "."
    else if (c == "[") { inb = 1; r = r "["; if (substr(g, i + 1, 1) == "!") { r = r "^"; i++ } }
    else if (index("\\^$.|()+{}", c)) r = r "\\" c
    else r = r c
  }
  return r "$"
}
function trim(x) { sub(/^[ \t]+/, "", x); sub(/[ \t]+$/, "", x); return x }
function readlines(file, arr,   n, l) { n = 0; while ((getline l < file) > 0) arr[++n] = l; close(file); return n }
# explain ID LABEL: "LINE|CATEGORY|reason" of the first line that explains
# the failure, "" if none; LINE is 0 for a line of rune that an xc1
# configuration inherits (not counted as used)
function explain(id, label,   k, i, ln) {
  for (k = 1; k <= ncand[id]; k++) {
    i = cand[id, k]
    ln = (id ~ cre[i]) ? dline[i] : 0
    if (label ~ lre[i]) return ln "|" cat[i] "|" why[i]
  }
  return ""
}
# the lines that can explain a failure of ID, in order
function candidates(id,   i) {
  for (i = 1; i <= ndev; i++)
    if (id ~ cre[i] ||
        (id ~ /^(xc1|rune):/ && cglob[i] == "rune" && (cat[i] == "RUNE-DEV" || cat[i] == "SPEC-AMBIGUOUS")))
      cand[id, ++ncand[id]] = i
}
function secs(x) { return sprintf("%.1f", x) }
BEGIN {
  # the deviations
  ndev = 0; lineno = 0
  while ((getline l < devfile) > 0) {
    lineno++
    if (l ~ /^[ \t]*(#|$)/) continue
    n = split(l, f, "|")
    ndev++
    dline[ndev] = lineno; cglob[ndev] = trim(f[1]); lglob[ndev] = trim(f[2]); cat[ndev] = trim(f[3])
    w = f[4]; for (k = 5; k <= n; k++) w = w "|" f[k]
    why[ndev] = trim(w)
    cre[ndev] = g2re(cglob[ndev]); lre[ndev] = g2re(lglob[ndev])
  }
  nids = readlines(idsfile, ids); ntests = readlines(testsfile, tests)
  for (a = 1; a <= nids; a++) candidates(ids[a])
  while ((getline l < dirsfile) > 0) { split(l, f, "\t"); dir[f[1]] = f[2] }
  print "# Basis Library suite\n\n| Configuration | Test | Checks | Pass | Explained | Unexplained | Not run |\n|---|---|---|---|---|---|---|" > report
  nun = 0; nx = 0
  for (a = 1; a <= nids; a++) {
    id = ids[a]; d = dir[id]
    tc = tp = tx = tf = tab = tna = 0
    for (b = 1; b <= ntests; b++) {
      t = tests[b]; r = d "/" t ".result"
      pass = xfail = fail = 0; absent = ""; na = ""; nfails = 0
      rc = (getline l < r)
      if (rc < 0) { unexplained[++nun] = id " @load/" t " -- no result"; tf++; continue }
      while (rc > 0) {
        if (l ~ /^PASS /) pass++
        else if (l ~ /^ABSENT /) absent = absent substr(l, 8) " "
        else if (l ~ /^NA /) na = na substr(l, 4) " "
        else if (l ~ /^FAIL /) {
          fails[++nfails] = l
          if (l ~ /^FAIL @load\/[^ ]* -- timed out after /) timedout[id, t] = 1
        }
        rc = (getline l < r)
      }
      close(r)
      printf "" > (d "/" t ".fails")
      for (k = 1; k <= nfails; k++) {
        print fails[k] >> (d "/" t ".fails")
        rest = substr(fails[k], 6); label = rest; sub(/ .*/, "", label); after = substr(rest, length(label) + 1)
        e = explain(id, label)
        if (e != "") {
          xfail++; ln = e; sub(/\|.*/, "", ln)
          if (ln > 0) used[ln, id] = 1
          x = e; sub(/^[^|]*\|/, "", x)
          xf[++nx] = id "|" label "|" x
        } else {
          fail++; unexplained[++nun] = id " " label after
        }
      }
      close(d "/" t ".fails")
      notrun = (absent != "" ? "absent: " absent : "") (na != "" ? "n/a: " na : "")
      printf "| %s | %s | %d | %d | %d | %d | %s|\n", id, t, pass + xfail + fail, pass, xfail, fail, notrun >> report
      tc += pass + xfail + fail; tp += pass; tx += xfail; tf += fail
      if (na != "") tna++
      if (absent != "") {
        tab++
        if (id ~ /^rune(:|$)/) {
          e = explain(id, "@absent/" t)
          if (e != "") {
            ln = e; sub(/\|.*/, "", ln); if (ln > 0) used[ln, id] = 1
            x = e; sub(/^[^|]*\|/, "", x); xf[++nx] = id "|@absent/" t "|" x
          } else { unexplained[++nun] = id " @absent/" t " -- lacks " absent; tf++ }
        }
      }
    }
    printf "%-28s %6d checks: %6d pass, %4d explained, %4d FAILED; of %d tests %d absent, %d n/a\n", id, tc, tp, tx, tf, ntests, tab, tna
  }
  status = 0
  if (nun > 0) {
    status = 1
    print "unexplained failures (add a fix, or a line to tests/basis/deviations.txt):"
    for (k = 1; k <= nun && k <= 40; k++) print "  " unexplained[k]
    if (nun > 40) print "  ... and " (nun - 40) " more in " report
  }
  for (k = 1; k <= nun; k++) print unexplained[k] > unexplainedfile
  # Stale deviations: a line must match a failure in every configuration of
  # this run that its configuration glob names (not a HOST-FLAKY line: that
  # failure comes and goes). The checks of a test that timed out in a
  # configuration, as the rune configuration reports them, may not have run:
  # a line that matches one of them is not stale there.
  if (filter == "") {
    for (key in timedout) {
      split(key, kk, SUBSEP); r = dir["rune"] "/" kk[2] ".result"
      while ((getline l < r) > 0) if (l ~ /^(PASS|FAIL) /) { split(l, f, " "); unrun[kk[1], ++nunrun[kk[1]]] = f[2] }
      close(r)
    }
    for (i = 1; i <= ndev; i++) {
      if (cat[i] == "HOST-FLAKY") continue
      for (a = 1; a <= nids; a++) {
        id = ids[a]
        if (id !~ cre[i] || ((dline[i], id) in used)) continue
        skip = 0
        for (k = 1; k <= nunrun[id]; k++) if (unrun[id, k] ~ lre[i]) { skip = 1; break }
        if (skip) continue
        print "stale deviation: tests/basis/deviations.txt:" dline[i] " (" cglob[i] " | " lglob[i] ") matches no failure of " id
        status = 1
      }
    }
  }
  # the rest of the report
  print "\n## Explained deviations\n\n| Configuration | Check | Category | Reason |\n|---|---|---|---|" >> report
  close(report)
  cmd = "sort | sed \"s/|/ | /g; s/^/| /; s/$/ |/\" >> \"" report "\""
  for (k = 1; k <= nx; k++) print xf[k] | cmd
  close(cmd)
  print "\n## Unexplained failures\n" >> report
  for (k = 1; k <= nun; k++) print "    " unexplained[k] >> report
  print "\n## Files of lib/basis that a host does not load (xc1)\n\n| Configuration | File | First error |\n|---|---|---|" >> report
  while ((getline l < droppedfile) > 0) print l >> report
  # timings: of each program, and of each probe
  ntime = 0; busy = 0
  for (a = 1; a <= nids; a++) {
    id = ids[a]; d = dir[id]; h = id; sub(/@.*/, "", h); sub(/^[a-z0-9]*:/, "", h)
    if (id ~ /^xc1:/ && (getline l < (d "/basis.time")) > 0) {
      split(l, f, " "); probe[id] = f[3]; probemode[id] = f[1] (f[1] == "probed" ? " " f[2] " loads" : "")
      busy += f[3]; newt[id "\t@probe"] = f[3]; close(d "/basis.time")
    }
    for (b = 1; b <= ntests; b++) {
      t = tests[b]; tf = d "/" t ".time"
      if ((getline l < tf) <= 0) continue
      close(tf); split(l, f, " ")
      tot = f[1] + 0; first = f[2] + 0; waitt = f[3] + 0
      cfgsum[id] += tot; cfgfall[id] += tot - first; cfgwait[id] += waitt; hostsum[h] += tot; busy += tot
      if (tot > cfgmax[id]) { cfgmax[id] = tot; cfgmaxt[id] = t }
      ntime++; ptot[ntime] = tot; pname[ntime] = id " " t; pfirst[ntime] = first
      newt[id "\t" t] = tot
    }
  }
  # timings.tsv: those of earlier runs, with this one on top
  while ((getline l < timings) > 0) { split(l, f, "\t"); k = f[1] "\t" f[2]; if (!(k in newt)) print l > newtimings }
  for (k in newt) printf "%s\t%.3f\n", k, newt[k] > newtimings
  close(newtimings)
  # statistics, to stdout and the report
  out = ""
  out = out sprintf("timing: %.1f s for the programs and probes on %d job slots, busy %.0f%% of the time (%.1f s of work)\n", wall, jobs, wall > 0 ? 100 * busy / (wall * jobs) : 0, busy)
  out = out "  configuration                work s  fallback s  slowest program\n"
  for (a = 1; a <= nids; a++) {
    id = ids[a]
    out = out sprintf("  %-28s %7s  %10s  %s (%s s)%s\n", id, secs(cfgsum[id]), secs(cfgfall[id]), cfgmaxt[id], secs(cfgmax[id]),
                      (id in probe) ? sprintf("; probe %s s, %s", secs(probe[id]), probemode[id]) : "")
  }
  hl = ""; for (h in hostsum) hl = hl sprintf(" %s %s s,", h, secs(hostsum[h]))
  sub(/,$/, "", hl)
  out = out "  by host:" hl "\n"
  # the slowest programs (a selection sort of the first 12)
  out = out "  slowest programs:"
  for (k = 1; k <= 12 && k <= ntime; k++) {
    m = k; for (j = k + 1; j <= ntime; j++) if (ptot[j] > ptot[m]) m = j
    x = ptot[k]; ptot[k] = ptot[m]; ptot[m] = x; x = pname[k]; pname[k] = pname[m]; pname[m] = x
    x = pfirst[k]; pfirst[k] = pfirst[m]; pfirst[m] = x
    out = out sprintf("%s %s %s s%s", k == 1 ? "" : ",", pname[k], secs(ptot[k]),
                      ptot[k] - pfirst[k] > 1 ? " (" secs(ptot[k] - pfirst[k]) " s fallback)" : "")
  }
  out = out "\n"
  printf "%s", out
  printf "%s", out > statsfile
  exit status
}'
status=$?
[ -f "$run/timings.new" ] && mv "$run/timings.new" "$timings"
{
  echo
  echo "## Timing"
  echo
  sed 's/^/    /' "$run/stats"
  echo "    report: $(since "$t_report") s"
} >> "$report"
echo "timing: report $(since "$t_report") s, all $(since "$t_run") s"
echo "report: ${report#"$root"/}"
exit $status
