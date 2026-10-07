#!/bin/sh
# The evaluation set of the second-generation collector (docs/testing.md,
# *Measuring a collector*; docs/plans/garbage-collector-v2.md, *The
# workloads*): every run of scripts/gc-eval.tsv on a candidate VM and on a
# baseline VM, interleaved, and the scores scripts/gc-eval-score.py gives
# them -- T (task-clock), M (peak resident memory) and P (pauses), per group
# and in all, with the worst cases.
#
#   scripts/gc-eval.sh [OPTION...] CANDIDATE BASELINE
#
#   --rounds N           rounds (3): each run is scored by its round with the
#                        least task-clock; the GC-stress tier and the 1 GB runs
#                        are run once (the set's rounds column)
#   --only NAME,...      only these runs, by their names or their groups
#   --extras             also the runs no score weighs (the set's 0 0 0 groups)
#   --mlton-compile      also Rune compiling MLton: 12 GiB of address space per
#                        VM, about 20 GB free and 20 minutes for the two;
#                        needs MLTON_SOURCES; never run without this flag
#   --candidate-opts S   VM options of the candidate (e.g. '--heap-fill 75'),
#   --baseline-opts S    and of the baseline
#   --out DIR            the runs and the report (tests/out/gc-eval)
#   --resume             keep the runs DIR holds and make only those missing
#                        (after an interruption, with the same options)
#   --prepare            compile what the runs need, and stop
#   --score              score what DIR holds, and stop
#   -j N                 compile jobs (4)
#
# Both VMs must take --gc-log FILE (docs/runtime.md, *The collector's log*).
# Every run is `cd DIR && ulimit -v KIB && perf stat -- /usr/bin/time --
# timeout S VM --gc-log FILE OPTIONS ARGUMENTS < INPUT`, its output in
# DIR/runs/NAME/{candidate,baseline}-R.*; without perf the task-clock is
# user + system time. The programs come from the tree: bin/rune.rbc and
# bin/runedoc.rbc (make), examples/benchmarks compiled by bin/rune -O2 --lint
# into DIR/bench, MLton's benchmarks by tests/external/run-mlton-bench.sh
# --prepare into tests/out/mlton-bench (skipped when MLTON_BENCH, its
# benchmark/tests, is missing).
#
# Environment:
#   GC_EVAL_LOCK     a command prefix under which each round is made, to have
#                    the machine to itself, e.g. 'flock /tmp/rune-timed'; it is
#                    let go for GC_EVAL_GAP seconds (60) between rounds, so that
#                    others waiting for it have it
#   GC_EVAL_MARGIN   kB of memory that must be free beyond a run's ulimit before
#                    it starts (8388608; 0 checks nothing); it waits up to an hour
#   MLTON_BENCH      MLton's benchmark/tests (run-mlton-bench.sh's default)
#   MLTON_SOURCES    for --mlton-compile: MLton's sources at 5fe943391 with
#                    mlton-rune.txt, the files in the order Rune compiles them
#
# Takes about 30 minutes at three rounds on the reference machine (15 a VM, of
# which the GC-stress tier is half), and the preparation a few more.
set -u
cd "$(dirname "$0")/.."
root=$(pwd)
self=$root/scripts/gc-eval.sh
tab=$(printf '\t')

# --round R: round R of the plan in DIR (GC_EVAL_OUT), the main loop's under
# the lock; with GC_EVAL_RESUME=1 a run made on both VMs is not made again
if [ "${1:-}" = --round ]; then
  r=$2
  cut -f 5,9 "$GC_EVAL_OUT/plan.tsv" | while IFS=$tab read -r name most; do
    [ "$most" = - ] || [ "$r" -le "$most" ] || continue
    d=$GC_EVAL_OUT/runs/$name
    [ "$GC_EVAL_RESUME" = 1 ] && [ -f "$d/candidate-$r.exit" ] && [ -f "$d/baseline-$r.exit" ] && continue
    sh "$self" --pair "$name" "$r" < /dev/null
  done
  exit 0
fi

# --pair NAME ROUND: one run of NAME on each VM, in an order that alternates
# with the round
if [ "${1:-}" = --pair ]; then
  name=$2; r=$3; out=$GC_EVAL_OUT
  line=$(awk -F '\t' -v n="$name" '$5 == n' "$out/plan.tsv")
  IFS=$tab read -r group wt wm wp name kind args expected rounds mem tmo <<EOF
$line
EOF
  dir=$out/runs/$name
  mkdir -p "$dir"
  output=$dir/output
  stdin=/dev/null
  case $kind in
    compiler) cwd=$root ;;
    mlton) cwd=$root/tests/out/mlton-bench
           extra=""; [ -f "$cwd/$args.args" ] && extra=$(cat "$cwd/$args.args")
           args="$args.rbc $extra" ;;
    bench) set -- $args; cwd=$out/bench/$1; stdin=$out/inputs/$name; args=prog.rbc ;;
    mlton-compile) cwd=$MLTON_SOURCES ;;
  esac
  boot="build/config.sml $(grep -v -E '^[[:space:]]*(#|$)' sources.txt | tr '\n' ' ') src/main/rune-main.sml"
  mlton=""; [ "$kind" = mlton-compile ] && mlton=$(tr '\n' ' ' < "$MLTON_SOURCES/mlton-rune.txt")
  args=$(printf '%s\n' "$args" | sed "s|@root|$root|g; s|@out|$output|g; s|@boot|$boot|g; s|@mlton|$mlton|g")
  perf=""
  [ "$GC_EVAL_PERF" = 1 ] && perf=perf
  one() {   # one WHO VM OPTIONS: the run, its files DIR/WHO-R.*
    base=$dir/$1-$r
    rm -f "$base".* "$output"
    if [ -r /proc/meminfo ] && [ "${GC_EVAL_MARGIN:-8388608}" -gt 0 ]; then
      need=$((mem + ${GC_EVAL_MARGIN:-8388608})); waited=0
      while [ "$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)" -lt "$need" ] && [ $waited -lt 3600 ]; do
        [ $waited = 0 ] && echo "gc-eval: $name waits for $need kB of free memory" >&2
        sleep 30; waited=$((waited + 30))
      done
    fi
    cut -d ' ' -f 1 /proc/loadavg > "$base.load" 2> /dev/null
    printf 'cd %s && ulimit -v %s && timeout %s %s --gc-log %s %s %s < %s\n' "$cwd" "$mem" "$tmo" "$2" "$base.gclog" "$3" "$args" "$stdin" > "$base.cmd"
    (
      cd "$cwd" || exit 2
      ulimit -v "$mem"
      # shellcheck disable=SC2086
      if [ -n "$perf" ]; then
        perf stat -x, -e task-clock,instructions:u,page-faults -o "$base.perf" -- \
          /usr/bin/time -f '%U %S %e %M' -o "$base.time" timeout "$tmo" "$2" --gc-log "$base.gclog" $3 $args \
          < "$stdin" > "$base.stdout" 2> "$base.stderr"
      else
        /usr/bin/time -f '%U %S %e %M' -o "$base.time" timeout "$tmo" "$2" --gc-log "$base.gclog" $3 $args \
          < "$stdin" > "$base.stdout" 2> "$base.stderr"
      fi
    )
    echo $? > "$base.exit"
    [ -f "$output" ] && mv "$output" "$base.output"
    echo "  $1 exit $(cat "$base.exit"), $(tail -1 "$base.time" 2> /dev/null | awk '{ printf "%.2f s user+sys, %.0f MiB", $1 + $2, $4 / 1024 }')"
  }
  echo "gc-eval: round $r, $name"
  if [ $((r % 2)) = 1 ]; then
    one candidate "$GC_EVAL_CANDIDATE" "$GC_EVAL_CANDIDATE_OPTS"
    one baseline "$GC_EVAL_BASELINE" "$GC_EVAL_BASELINE_OPTS"
  else
    one baseline "$GC_EVAL_BASELINE" "$GC_EVAL_BASELINE_OPTS"
    one candidate "$GC_EVAL_CANDIDATE" "$GC_EVAL_CANDIDATE_OPTS"
  fi
  exit 0
fi

# --compile NAME: examples/benchmarks' NAME into DIR/bench/NAME/prog.rbc, as
# scripts/measure-benchmarks.sh compiles it, with its data files
if [ "${1:-}" = --compile ]; then
  name=$2; dest=$GC_EVAL_OUT/bench/$name
  line=$(awk -F '\t' -v n="$name" '$1 == n && $2 == "normal"' examples/benchmarks/manifest.tsv)
  [ -n "$line" ] || { echo "gc-eval: no program $name in examples/benchmarks/manifest.tsv" >&2; exit 1; }
  mkdir -p "$dest"
  set --
  for s in $(printf '%s\n' "$line" | cut -f 7 | tr ',' ' '); do set -- "$@" "examples/benchmarks/$s"; done
  # kept from an earlier preparation unless a source or the compiler is newer
  [ -f "$dest/prog.rbc" ] && [ -z "$(find "$@" bin/rune.rbc -newer "$dest/prog.rbc")" ] && exit 0
  for p in $(printf '%s\n' "$line" | cut -f 11 | tr ',' ' '); do
    [ "$p" = - ] && continue
    mkdir -p "$dest/$(dirname "$p")" && cp "examples/benchmarks/$name/$p" "$dest/$p"
  done
  (ulimit -v 6291456; timeout 900 bin/rune -O2 --lint "$@" -o "$dest/prog.rbc.new") > "$dest/compile.log" 2>&1 &&
    mv "$dest/prog.rbc.new" "$dest/prog.rbc" && exit 0
  echo "gc-eval: $name does not compile: $(head -3 "$dest/compile.log")" >&2
  exit 1
fi

usage() {
  sed -n '9,26p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}
rounds=3 only="" extras=0 mlton_compile=0 copts="" bopts="" out=tests/out/gc-eval mode=all jobs=4 resume=0
while [ $# -gt 0 ]; do
  case $1 in
    --rounds) rounds=$2; shift 2 ;;
    --only) only=$2; shift 2 ;;
    --extras) extras=1; shift ;;
    --mlton-compile) mlton_compile=1; shift ;;
    --candidate-opts) copts=$2; shift 2 ;;
    --baseline-opts) bopts=$2; shift 2 ;;
    --out) out=$2; shift 2 ;;
    --resume) resume=1; shift ;;
    --prepare) mode=prepare; shift ;;
    --score) mode=score; shift ;;
    -j) jobs=$2; shift 2 ;;
    -*) usage ;;
    *) break ;;
  esac
done
mkdir -p "$out"
out=$(cd "$out" && pwd)
if [ $mode = score ]; then
  exec python3 scripts/gc-eval-score.py "$out"
fi
[ $# = 2 ] || usage
case $rounds in ''|*[!0-9]*|0) echo "gc-eval: --rounds wants a number from 1" >&2; exit 2 ;; esac
abspath() { case $1 in /*) echo "$1" ;; */*) echo "$root/$1" ;; *) command -v "$1" ;; esac; }
candidate=$(abspath "$1"); baseline=$(abspath "$2")
for vm in "$candidate" "$baseline"; do
  [ -x "$vm" ] || { echo "gc-eval: $vm is not a program" >&2; exit 2; }
done
for f in bin/rune bin/rune.rbc bin/runedoc.rbc; do
  [ -f "$f" ] || { echo "gc-eval: no $f: run make first" >&2; exit 2; }
done
mlton_bench=${MLTON_BENCH:-/home/ruud/reference/mlton/benchmark/tests}
if [ $mlton_compile = 1 ] && [ ! -f "${MLTON_SOURCES:-}/mlton-rune.txt" ]; then
  echo "gc-eval: --mlton-compile needs MLTON_SOURCES, a directory with mlton-rune.txt" >&2; exit 2
fi

# the plan: the set's lines that are run, in its order
grep -v '^#' scripts/gc-eval.tsv | while IFS=$tab read -r group wt wm wp name kind args expected rest; do
  [ -n "$name" ] || continue
  [ "$wt$wm$wp" = 000 ] && [ $extras = 0 ] && continue
  [ "$kind" = mlton-compile ] && [ $mlton_compile = 0 ] && continue
  if [ -n "$only" ]; then
    hit=0 saved=$IFS IFS=,
    for w in $only; do [ "$w" = "$name" ] || [ "$w" = "$group" ] && hit=1; done
    IFS=$saved
    [ $hit = 1 ] || continue
  fi
  if [ "$kind" = mlton ] && [ ! -d "$mlton_bench" ]; then
    echo "gc-eval: no $mlton_bench (MLTON_BENCH): $name is not run" >&2; continue
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$group" "$wt" "$wm" "$wp" "$name" "$kind" "$args" "$expected" "$rest"
done > "$out/plan.tsv"
[ -s "$out/plan.tsv" ] || { echo "gc-eval: no run selected" >&2; exit 2; }
cp scripts/gc-eval.tsv "$out/set.tsv"

# the programs
export GC_EVAL_OUT=$out
status=0
benches=$(awk -F '\t' '$6 == "bench" { split($7, w, " "); print w[1] }' "$out/plan.tsv" | sort -u)
if [ -n "$benches" ]; then
  echo "gc-eval: compiling $(echo $benches | wc -w) programs of examples/benchmarks into $out/bench"
  echo "$benches" | xargs -P "$jobs" -I{} sh "$self" --compile {} || status=1
fi
awk -F '\t' -v OFS='\t' '$6 == "bench" { print $5, $7, $8 }' "$out/plan.tsv" | while IFS=$tab read -r name args expected; do
  set -- $args
  program=$1; shift
  if [ "${1:-}" = @normal ]; then
    line=$(awk -F '\t' -v n="$program" '$1 == n && $2 == "normal"' examples/benchmarks/manifest.tsv)
    set -- $(printf '%s\n' "$line" | cut -f 5)
    expected=$(cat "examples/benchmarks/$(printf '%s\n' "$line" | cut -f 6)")
  fi
  mkdir -p "$out/inputs"
  printf '%s\n%s\n%s\n' "$program" "$*" "$expected" > "$out/inputs/$name"
done
# MLton's, unless their bytecode is there and newer than the compiler
mltons=""
for n in $(awk -F '\t' '$6 == "mlton" { print $7 }' "$out/plan.tsv"); do
  rbc=tests/out/mlton-bench/$n.rbc
  [ -f "$rbc" ] && [ -z "$(find bin/rune.rbc -newer "$rbc")" ] || mltons="$mltons $n"
done
if [ -n "$mltons" ]; then
  echo "gc-eval: preparing $(echo $mltons | wc -w) of MLton's benchmarks in tests/out/mlton-bench"
  # shellcheck disable=SC2086
  (ulimit -v 6291456; MLTON_BENCH=$mlton_bench sh tests/external/run-mlton-bench.sh --prepare --all -j "$jobs" $mltons) \
    > "$out/mlton-prepare.log" 2>&1 || { grep -v '^PREPARED' "$out/mlton-prepare.log" >&2; status=1; }
fi
[ $mode = prepare ] && exit $status

# the runs: round by round, each run of the plan on both VMs
GC_EVAL_PERF=0
perf stat -x, -e task-clock -o /dev/null -- true > /dev/null 2>&1 && GC_EVAL_PERF=1
[ $resume = 1 ] || rm -rf "$out/runs"
export GC_EVAL_RESUME=$resume GC_EVAL_PERF GC_EVAL_CANDIDATE=$candidate GC_EVAL_BASELINE=$baseline \
  GC_EVAL_CANDIDATE_OPTS="$copts" GC_EVAL_BASELINE_OPTS="$bopts" MLTON_SOURCES="${MLTON_SOURCES:-}"
{
  echo "candidate $candidate $copts"
  echo "baseline $baseline $bopts"
  echo "rounds $rounds"
  echo "perf $GC_EVAL_PERF"
  echo "date $(date -u +%FT%TZ)"
  echo "revision $(git rev-parse --short HEAD 2> /dev/null) $(git status --porcelain 2> /dev/null | wc -l) changed"
  echo "machine $(uname -srm)"
} > "$out/meta"
echo "gc-eval: $(wc -l < "$out/plan.tsv") runs, $rounds rounds, $candidate against $baseline; in $out"
r=1
while [ $r -le "$rounds" ]; do
  # shellcheck disable=SC2086
  ${GC_EVAL_LOCK:-} sh "$self" --round "$r" < /dev/null
  [ -n "${GC_EVAL_LOCK:-}" ] && [ $r -lt "$rounds" ] && sleep "${GC_EVAL_GAP:-60}"
  r=$((r + 1))
done
python3 scripts/gc-eval-score.py "$out" | tee "$out/report.md"
exit $status
