#!/bin/sh
# Serial process/OS adapter. Manifest checks, workload validation and reports
# are SML97. No instrumented run supplies a headline timing sample.
set -eu
cd "$(dirname "$0")/.."
root=$(pwd)
action=${1:-time}
[ "$#" = 0 ] || shift
profile=${BENCH_PROFILE:-normal}
configs=${BENCH_CONFIGS:-rune,native:mlton,native:smlnj-legacy,native:polyml}
filter=${BENCH_FILTER:-}
samples=${BENCH_SAMPLES:-10}
rounds=${BENCH_REPETITIONS:-10}
mode=${BENCH_MODE:-fresh}
level=${BENCH_LEVEL:-2}
base_vm_options=${RUNEVM_OPTIONS:-}
update=0
while [ "$#" -gt 0 ]; do
  case $1 in
    --profile) profile=$2; shift 2 ;;
    --configs) configs=$2; shift 2 ;;
    --filter) filter=$2; shift 2 ;;
    --samples) samples=$2; shift 2 ;;
    --mode) mode=$2; shift 2 ;;
    --repetitions) rounds=$2; shift 2 ;;
    --level) level=$2; shift 2 ;;
    --update-budgets) update=1; shift ;;
    *) echo "unknown measurement option: $1" >&2; exit 2 ;;
  esac
done
case $action in time|count|stats) ;; *) echo 'action must be time, count or stats' >&2; exit 2 ;; esac
if [ "$action" = time ]; then
  case " $base_vm_options " in
    *' --count '*|*' --stats '*|*' --jit-stats '*|*' --trace '*)
      echo 'instrumented VM options require a separate count/stats run' >&2; exit 2 ;;
  esac
fi
case $mode in fresh) rounds=1 ;; repeated) ;; *) echo 'mode must be fresh or repeated' >&2; exit 2 ;; esac
case $level in 0|2) ;; *) echo 'level must be 0 or 2' >&2; exit 2 ;; esac
for value in "$samples" "$rounds"; do
  case $value in ''|*[!0-9]*) echo 'invalid sample/repetition count' >&2; exit 2 ;; esac
  [ "$value" -ge 1 ] && [ "$value" -le 100000 ] || exit 2
done
if [ "$action" != time ]; then
  samples=1; rounds=1; mode=fresh
  [ "$configs" != rune,native:mlton,native:smlnj-legacy,native:polyml ] || configs=rune,rune:opt,rune:new,rune:jit
fi
[ "$action" = count ] || [ "$update" = 0 ] || { echo 'budgets apply only to count runs' >&2; exit 2; }
LC_ALL=C; export LC_ALL
TZ='NST3:30NDT,M3.2.0,M11.1.0'; export TZ
[ -x /usr/bin/time ] || { echo '/usr/bin/time is required' >&2; exit 2; }
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/measurement.XXXXXX")
echo "BENCH MEASUREMENT $out"
bin/runevm-stack build/bench-catalog.rbc --list "$profile" "$filter" > "$out/jobs.tsv"
[ -s "$out/jobs.tsv" ] || { echo 'no benchmark matches' >&2; exit 2; }
printf 'benchmark\tprofile\tconfig\tlevel\tphase\tprocess\tround\tstatus\tseconds\tuser_seconds\tsystem_seconds\tmax_rss_kib\tinstructions\tbytes\tobjects\tartifact\n' > "$out/samples.tsv"
{
  printf 'date_utc\t%s\nrevision\t%s\n' "$(date -u +%FT%TZ)" "$(git rev-parse HEAD)"
  printf 'dirty\t%s\naction\t%s\nmode\t%s\nsamples\t%s\nrepetitions\t%s\nlevel\t%s\nprofile\t%s\nconfigs\t%s\nfilter\t%s\n' \
    "$(git status --porcelain | wc -l)" "$action" "$mode" "$samples" "$rounds" "$level" "$profile" "$configs" "$filter"
  printf 'machine\t%s\n' "$(uname -a)"
  printf 'time_tool\t%s\n' "$(/usr/bin/time --version | head -1)"
  printf 'runtime_options\t%s\n' "${RUNEVM_OPTIONS:-}"
  printf 'timezone\t%s\nlocale\t%s\n' "$TZ" "$LC_ALL"
  printf 'limit_method\tAS except PolyML data quota and capped managed heap\n'
  printf 'compile_samples\t1 fresh build per workload/configuration\n'
  printf 'os_clock_resolution\tGNU time wall seconds printed to hundredths\n'
  printf 'in_process_clock\tSML Time.now, formatted to nanoseconds; precision is host dependent\n'
  printf 'native_options\tcompiler defaults; level column refers to Rune only\n'
} > "$out/metadata.tsv"
git diff --binary HEAD > "$out/worktree.patch"
git status --porcelain > "$out/worktree-status.txt"
cp examples/benchmarks/manifest.tsv examples/benchmarks/upstreams.tsv "$out/"
mkdir -p "$out/tool-sources"
for path in scripts/measure-benchmarks.sh tests/basis/run-matrix.sh examples/benchmarks/shared/catalog.sml examples/benchmarks/shared/catalog-main.sml examples/benchmarks/shared/report.sml examples/benchmarks/shared/report-main.sml examples/benchmarks/shared/counts.sml examples/benchmarks/shared/counts-main.sml; do
  destination=$out/tool-sources/$path
  mkdir -p "$(dirname "$destination")"
  cp "$path" "$destination"
done
(cd "$out" && find tool-sources -type f -print0 | sort -z | xargs -0 sha256sum) > "$out/tool-sources.sha256"
{ uname -a; cat /proc/cpuinfo; cat /proc/meminfo; cat /proc/loadavg; } > "$out/machine.txt"
: > "$out/configurations.tsv"
status=0

# Every command has controlled streams and a quota. GNU time measures only
# this phase, including quota setup and process startup, never source copying.
execute() {
  phase_dir=$1; quota=$2; shift 2
  mkdir -p "$phase_dir"
  printf '%s\n' "$@" > "$phase_dir/command.txt"
  printf 'timeout_seconds\t%s\nmemory_kib\t%s\nquota\t%s\nruntime_options\t%s\n' "$seconds" "$memory" "$quota" "${RUNEVM_OPTIONS:-}" > "$phase_dir/settings.tsv"
  phase_exit=0
  /usr/bin/time -f '%e\t%U\t%S\t%M' -o "$phase_dir/os.tsv" \
    timeout "$seconds" sh -c 'ulimit -c 0; ulimit -"$1" "$2" || exit 125; shift 2; exec "$@"' \
      bench-limit "$quota" "$memory" "$@" < "$phase_input" > "$phase_dir/stdout" 2> "$phase_dir/stderr" || phase_exit=$?
  printf '%s\n' "$phase_exit" > "$phase_dir/exit"
}
classify() {
  category=pass
  if [ "$phase_exit" = 124 ]; then category=timeout
  elif [ "$phase_exit" = 125 ]; then category=limit-setup-failure
  elif grep -Eiq 'out of memory|allocation failed|cannot allocate memory|heap limit|insufficient memory|unable to reserve' "$phase_dir/stderr" "$phase_dir/stdout"; then category=memory-limit
  elif [ "$phase_exit" != 0 ]; then category=$1
  fi
}
record() {
  record_phase=$1; record_process=$2; record_round=$3; record_category=$4; record_seconds=${5:-}
  metrics=$(tail -1 "$phase_dir/os.tsv" 2>/dev/null || true)
  [ -n "$metrics" ] || metrics=$(printf '0\t0\t0\t0')
  os_seconds=$(printf '%s\n' "$metrics" | cut -f1)
  [ -n "$record_seconds" ] || record_seconds=$os_seconds
  printf '%s\t%s\t%s\tO%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$name" "$profile" "$id" "$level" "$record_phase" "$record_process" "$record_round" "$record_category" \
    "$record_seconds" "$(printf '%s\n' "$metrics" | cut -f2-)" "$counters" "${phase_dir#"$out"/}" >> "$out/samples.tsv"
}
validate() {
  classify runtime-failure
  if grep -Eq '^FAIL .* -- (incorrect result|expected )' "$phase_dir/stdout"; then category=incorrect-result; fi
  if [ "$category" = pass ]; then
    if ! grep -q "^SUMMARY $rounds checks, 0 failed$" "$phase_dir/stdout" || \
       grep -q '^FAIL ' "$phase_dir/stdout" || \
       [ "$(grep -c '^PASS ' "$phase_dir/stdout")" != "$rounds" ]; then category=incorrect-result; fi
  fi
  [ "$category" = pass ] || status=1
}
stage_data() {
  destination=$1
  mkdir -p "$destination"
  if [ "$input_files" != - ]; then
    for path in $input_files; do
      mkdir -p "$destination/$(dirname "$path")"
      cp "$root/examples/benchmarks/$name/$path" "$destination/$path"
    done
  fi
}
while IFS="$(printf '\t')" read -r name seconds memory sources args expected input_files; do
  echo "BENCH MEASURE $name $profile $action"
  for spec in $(printf '%s' "$configs" | tr ',' ' '); do
    RUNEVM_OPTIONS=$base_vm_options; export RUNEVM_OPTIONS
    config_dir=$out/$name/$(printf '%s' "$spec" | tr ':/' '--')
    mkdir -p "$config_dir"
    id=$spec; counters=$(printf '%s\t%s\t%s' - - -)
    if ! sh tests/basis/run-matrix.sh --configs "$spec" --resolve-out "$config_dir/config.tsv" < /dev/null > "$config_dir/resolve.log" 2>&1; then
      phase_dir=$config_dir; record configuration 0 0 missing-configuration 0; status=1; continue
    fi
    # Alias groups are expanded by the caller into one row per configuration.
    [ "$(wc -l < "$config_dir/config.tsv")" = 1 ] || { echo 'use explicit configurations, not matrix groups' >&2; exit 2; }
    id=$(cut -f1 "$config_dir/config.tsv")
    kind=$(cut -f2 "$config_dir/config.tsv")
    host=$(cut -f3 "$config_dir/config.tsv")
    compiler=$(cut -f4 "$config_dir/config.tsv")
    runtime=$(cut -f5 "$config_dir/config.tsv")
    cat "$config_dir/config.tsv" >> "$out/configurations.tsv"
    if [ "$kind" = xc1 ] || { [ "$action" != time ] && [ "$kind" != rune ]; }; then
      phase_dir=$config_dir; record configuration 0 0 missing-configuration 0; status=1; continue
    fi
    bundle=$config_dir/build
    mkdir -p "$bundle/sources"
    : > "$bundle/identities.tsv"; : > "$bundle/sources.txt"
    n=0
    for source in $sources; do
      if [ "$action" = time ] && [ "$source" = shared/main.sml ]; then source=shared/measure.sml; fi
      n=$((n+1)); target=$bundle/sources/$n.sml
      cp "$root/examples/benchmarks/$source" "$target"
      printf '%s\n' "$target" >> "$bundle/sources.txt"
      printf '%s\t%s\n' "$source" "$(sha256sum < "$target" | cut -d' ' -f1)" >> "$bundle/identities.tsv"
    done
    cp "$root/examples/benchmarks/$expected" "$bundle/expected"
    { printf '%s\n%s\n' "$name" "$args"; cat "$bundle/expected"; [ "$action" != time ] || printf '%s\n' "$rounds"; } > "$config_dir/input"
    stage_data "$bundle/data"
    (cd "$bundle" && find sources data -type f -print0 | sort -z | xargs -0 sha256sum; sha256sum expected) > "$bundle/sha256.tsv"
    sha256sum "$compiler" > "$bundle/compiler.sha256"
    if [ "$kind" = rune ]; then
      sha256sum "$runtime" > "$bundle/runtime.sha256"
      (cd "$root" && sha256sum lib/basis/MANIFEST lib/basis/*.sml) > "$bundle/basis.sha256"
      sha256sum "$root/bin/rune.rbc" "$root/bin/rune.stack.rbc" "$root/bin/runevm-stack" "$root/bin/runevm" > "$bundle/rune-payloads.sha256"
    fi
    # Portable main plus the thin host-specific launch/export adapter.
    if [ "$action" = time ]; then
      echo 'val _ = OS.Process.exit (BenchMeasure.main ())' > "$bundle/launch.sml"
      printf '%s\n' "$bundle/launch.sml" >> "$bundle/sources.txt"
    fi
    set --
    while IFS= read -r source; do set -- "$@" "$source"; done < "$bundle/sources.txt"
    quota=v; [ "$host" != polyml ] || quota=d
    phase_input=/dev/null
    compile_phase=compile
    case $kind:$host in
      rune:*)
        execute "$bundle/compile" "$quota" "$compiler" "-O$level" --lint "$@" -o "$bundle/prog.rbc"
        run_command=$runtime; run_file=$bundle/prog.rbc
        if [ "$host" = opt ] && [ "$phase_exit" = 0 ]; then
          # Native translation is a separately measured compile phase.
          classify compile-error; record compile 0 0 "$category"
          opt=${RUNEOPT:-$root/bin/runeopt-mlton}
          execute "$bundle/native-compile" "$quota" "$opt" "$bundle/prog.rbc" -o "$bundle/prog"
          run_command=$bundle/prog; run_file=""
          compile_phase=native-compile
        fi
        ;;
      native:mlton|native:mlkit)
        { printf '%s\n' '$(SML_LIB)/basis/basis.mlb'; printf '%s\n' "$@"; } > "$bundle/prog.mlb"
        if [ "$host" = mlton ]; then
          execute "$bundle/compile" "$quota" "$compiler" -output "$bundle/prog" "$bundle/prog.mlb"
        else
          export SML_LIB=$runtime
          execute "$bundle/compile" "$quota" "$compiler" --no_messages -o "$bundle/prog" "$bundle/prog.mlb"
        fi
        run_command=$bundle/prog; run_file=""
        ;;
      native:smlnj-legacy|native:smlnj32|native:smlnj-dev)
        # Export declarations without the portable launch file. The heap image
        # runs main only on invocation, and never includes compiler loading.
        { while IFS= read -r source; do
            [ "$source" = "$bundle/launch.sml" ] || printf 'val _ = use "%s";\n' "$source"
          done < "$bundle/sources.txt"
          printf 'val _ = SMLofNJ.exportFn ("%s/prog", fn _ => BenchMeasure.main ());\n' "$bundle"
          echo 'val _ = OS.Process.exit OS.Process.success;'
        } > "$bundle/export.sml"
        execute "$bundle/compile" "$quota" "$compiler" "$bundle/export.sml"
        if ! ls "$bundle"/prog.* > /dev/null 2>&1; then phase_exit=1; fi
        run_command=$compiler; run_file=@SMLload=$bundle/prog
        ;;
      native:polyml)
        { while IFS= read -r source; do
            [ "$source" = "$bundle/launch.sml" ] || printf 'val _ = use "%s";\n' "$source"
          done < "$bundle/sources.txt"
          echo 'fun main () = OS.Process.exit (BenchMeasure.main ());'
        } > "$bundle/export.sml"
        execute "$bundle/compile" "$quota" "$(dirname "$compiler")/polyc" -b "$compiler" -o "$bundle/prog" "$bundle/export.sml"
        run_command=$bundle/prog; run_file=""
        ;;
      *) phase_exit=1; phase_dir=$bundle; echo 'unsupported configuration' > "$bundle/stderr" ;;
    esac
    classify compile-error
    record "$compile_phase" 0 0 "$category"
    if [ "$category" != pass ]; then status=1; continue; fi
    sha256sum "$bundle"/prog* > "$bundle/artifacts.sha256"
    phase_input=$config_dir/input
    process=0
    while [ "$process" -le "$samples" ]; do
      if [ "$process" = 0 ]; then run_phase=correctness; else run_phase=$mode; fi
      work=$config_dir/$run_phase.$process
      stage_data "$work/work"
      if [ "$kind" = rune ] && [ "$host" != opt ]; then
        cp "$bundle/prog.rbc" "$work/work/prog.rbc"; run_file=prog.rbc
      elif [ -f "$bundle/prog" ]; then
        cp "$bundle/prog" "$work/work/prog"; run_command=./prog
      fi
      set -- "$run_command"
      [ "$host" != new ] || set -- "$@" --jit=off
      [ "$action" != count ] || set -- "$@" --count
      [ "$action" != stats ] || set -- "$@" --stats
      [ -z "$run_file" ] || set -- "$@" "$run_file"
      printf '%s\n' "$@" > "$work/command.txt"
      # Native Rune consumes VM options via this documented environment.
      if [ "$host" = opt ]; then
        RUNEVM_NAME=prog.rbc; export RUNEVM_NAME
        RUNEVM_OPTIONS=$base_vm_options
        [ "$action" != count ] || RUNEVM_OPTIONS="$RUNEVM_OPTIONS --count"
        [ "$action" != stats ] || RUNEVM_OPTIONS="$RUNEVM_OPTIONS --stats"
        export RUNEVM_OPTIONS
        set -- ./prog
      fi
      if [ "$host" = polyml ]; then set -- "$@" -H 16 --maxheap "$((memory/2048))" --stackspace 64; fi
      (cd "$work/work" && execute "$work" "$quota" "$@"; echo "$phase_exit" > "$work/exit")
      phase_dir=$work; phase_exit=$(cat "$work/exit")
      validate
      if [ "$action" = time ] && [ "$category" = pass ] && \
         [ "$(grep -c '^SAMPLE ' "$work/stdout")" != "$rounds" ]; then category=incorrect-result; status=1; fi
      if [ "$action" = count ] && [ "$category" = pass ]; then
        counters=$(sed -n 's/^runevm: count: \([0-9]*\) instructions, \([0-9]*\) bytes, \([0-9]*\) objects$/\1\t\2\t\3/p' "$work/stderr" | tail -1)
        if [ -z "$counters" ]; then category=missing-counters; status=1; counters=$(printf '%s\t%s\t%s' - - -); fi
      fi
      if [ "$process" = 0 ]; then record correctness 0 0 "$category"
      elif [ "$action" = count ]; then record count "$process" 1 "$category"
      elif [ "$action" = stats ]; then record stats "$process" 1 "$category"
      elif [ "$mode" = fresh ] || [ "$category" != pass ]; then record "$mode" "$process" 1 "$category"
      else
        sed -n 's/^SAMPLE //p' "$work/stdout" | while read -r round elapsed; do record repeated "$process" "$round" pass "$elapsed"; done
      fi
      [ "$category" = pass ] || break
      process=$((process+1))
    done
  done
done < "$out/jobs.tsv"
if [ "$action" = count ]; then
  budget_mode=check; [ "$update" = 0 ] || budget_mode=update
  # A failed comparison must never publish new baselines.
  if [ "$status" = 0 ]; then
    count_exit=0
    mkdir -p "$out/count-check"
    bin/runevm-stack build/bench-counts.rbc "$out/samples.tsv" examples/benchmarks/count-budgets.tsv "$budget_mode" > "$out/count-check/stdout" 2> "$out/count-check/stderr" || count_exit=$?
    phase_dir=$out/count-check
    counters=$(printf '%s\t%s\t%s' - - -)
    category=pass
    if [ "$count_exit" != 0 ]; then
      status=1; category=count-check-failure
      if grep -q 'budget exceeded' "$phase_dir/stderr"; then category=count-budget; fi
      if grep -q 'disagree' "$phase_dir/stderr"; then category=count-mismatch; fi
    fi
    record count-check 0 0 "$category" 0
    cat "$phase_dir/stdout" "$phase_dir/stderr"
  fi
fi
bin/runevm-stack build/bench-report.rbc "$out/samples.tsv" > "$out/report.md"
echo "BENCH REPORT $out/report.md"
exit "$status"
