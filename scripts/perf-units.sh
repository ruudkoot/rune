#!/bin/sh
# What a compile costs, phase by phase, and the measurements the incremental
# roadmap's decisions rest on (docs/plans/incremental-compilation.md, M1):
#   scripts/perf-units.sh [--runs N] [--configs C1,C2,...] [--corpus DIR] [--mlton DIR]
#                         [phases|mid|globals]...
# phases (the default) compiles every program with every configuration under
# --pass-stats, N times (5 unless --runs says otherwise), and keeps the run
# with the least wall time. Its columns are that run's wall time and the
# processor time of each stage --pass-stats names (both shakes added
# together). The front end's lines per second are the lines of every file
# the compile reads -- the basis files `--basis-deps` names and the
# program's own -- over parse and elaborate.
# The configurations are the compiler on: tier2 (bin/runevm as bin/rune runs
# it, tiering up to tier 2), interp (--jit=off), baseline (--jit=baseline),
# stack (bin/runevm-stack running bin/rune.stack.rbc) and mlton (MLton's
# build, bin/rune-mlton). All of them write register bytecode. The programs
# are hello (examples/hello.sml), two (two lines that use List, Int, String
# and TextIO), basis (hello with --basis all, every file of the basis
# library), compiler (the compiler's own sources, BOOT_SRCS) and corpus (the
# harness of rune-corpus-sml97, when --corpus DIR or RUNE_CORPUS names it)
# and mlton (MLton's compiler, 606 files and about 198,000 lines, when
# --mlton DIR or MLTON_SOURCES names a checkout of MLton at 5fe943391 whose
# mlton/mlton-rune.txt lists the files in the order Rune compiles them, as
# scripts/gc-eval.sh wants it). mlton runs once, on tier2 and mlton only,
# under `ulimit -v 12582912` with --heap-limit 5368709120, and only when
# `free` shows 20 GB available: it takes minutes and gigabytes.
# mid writes the compiler's own Mid as text (--dump-after mid) and reads it
# back with --read-mid, against the front end and translation that made it
# (D6: text or binary Mid).
# globals compiles programs of N top-level values that then allocate 384 MB
# of short-lived lists, at -O0 so that every global is kept, and prints the
# minor collections and their processor time (from --gc-log) at each N: the globals are roots of every minor collection
# (docs/runtime.md, *The roots*), and a REPL session adds them all the time.
# The tables are written to stdout as Markdown; the raw output is left in
# tests/out/perf-units/.
set -u
runs=5
configs="tier2,interp,baseline,stack,mlton"
corpus=${RUNE_CORPUS:-}
mlton=${MLTON_SOURCES:-}
parts=""
usage="usage: scripts/perf-units.sh [--runs N] [--configs C1,C2,...] [--corpus DIR] [--mlton DIR] [phases|mid|globals]..."
while [ $# -gt 0 ]; do
  case "$1" in
    --runs) runs=$2; shift 2 ;;
    --configs) configs=$2; shift 2 ;;
    --corpus) corpus=$2; shift 2 ;;
    --mlton) mlton=$2; shift 2 ;;
    phases|mid|globals) parts="$parts $1"; shift ;;
    *) echo "$usage" >&2; exit 2 ;;
  esac
done
[ -n "$parts" ] || parts=phases
cd "$(dirname "$0")/.."
root=$(pwd)
out=$root/tests/out/perf-units
mkdir -p "$out"
heap=67108864
boot_srcs="build/config.sml $(grep -v '^[[:space:]]*#' sources.txt | grep -v '^[[:space:]]*$' | tr '\n' ' ') src/main/rune-main.sml"
for f in bin/runevm bin/runevm-stack bin/rune.rbc bin/rune.stack.rbc bin/rune-mlton; do
  [ -e "$f" ] || { echo "perf-units: $f is missing (make all bin/rune.stack.rbc)" >&2; exit 2; }
done

cat > "$out/two.sml" <<'EOF'
val xs = List.map Int.toString [1, 2, 3]
val () = TextIO.output (TextIO.stdOut, String.concatWith " " xs ^ "\n")
EOF

# compiler CONFIG ARGS...: run the compiler of CONFIG on ARGS
compiler() {
  c=$1; shift
  case "$c" in
    tier2) bin/runevm --heap-size $heap bin/rune.rbc --lib lib "$@" ;;
    interp) bin/runevm --jit=off --heap-size $heap bin/rune.rbc --lib lib "$@" ;;
    baseline) bin/runevm --jit=baseline --heap-size $heap bin/rune.rbc --lib lib "$@" ;;
    stack) bin/runevm-stack --heap-size $heap bin/rune.stack.rbc --lib lib "$@" ;;
    mlton) bin/rune-mlton "$@" ;;
    *) echo "perf-units: no configuration $c" >&2; exit 2 ;;
  esac
}

# the arguments of each program, from the repository's root
program_args() {
  case "$1" in
    hello) echo "examples/hello.sml" ;;
    two) echo "$out/two.sml" ;;
    basis) echo "--basis all examples/hello.sml" ;;
    compiler) echo "$boot_srcs" ;;
    corpus) (cd "$corpus" && printf "$corpus/%s " $(cat sources.txt) && echo "$corpus/src/main.sml") ;;
    mlton) echo "--type-work=1000000000 $(sed "s|^|$mlton/mlton/|" "$mlton/mlton/mlton-rune.txt" | tr '\n' ' ')" ;;
  esac
}

# the lines of every file a compile of ARGS reads
lines_read() {
  files=$(bin/rune-mlton --basis-deps "$@" | sed "s|^\([^/]\)|lib/basis/\1|")
  for a in "$@"; do case "$a" in -*) ;; *) [ -f "$a" ] && files="$files $a" ;; esac; done
  cat $files | wc -l
}

now() { date +%s%N; }

phases() {
  programs="hello two basis compiler"
  [ -n "$corpus" ] && [ -f "$corpus/sources.txt" ] && programs="$programs corpus"
  if [ -n "$mlton" ] && [ -f "$mlton/mlton/mlton-rune.txt" ]; then
    if [ "$(free -g | awk '/^Mem:/ { print $7 }')" -ge 20 ]; then programs="$programs mlton"
    else echo "perf-units: less than 20 GB available; mlton left out" >&2; fi
  fi
  : > "$out/phases.txt"
  echo "| Compiler | Program | wall | parse | elaborate | translate | mid | shake | lift | workers | simplify | lower | registers | lines read | lines/s, front end |"
  echo "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|"
  for p in $programs; do
    args=$(program_args $p)
    lines=$(lines_read $args)
    cs=$(echo "$configs" | tr ',' ' ')
    n=$runs
    if [ $p = mlton ]; then cs=$(echo "$cs" | tr ' ' '\n' | grep -x 'tier2\|mlton' | tr '\n' ' '); n=1; fi
    for c in $cs; do
      best=""
      i=0
      while [ $i -lt "$n" ]; do
        t0=$(now)
        # shellcheck disable=SC2086
        if [ $p = mlton ]; then
          (ulimit -v 12582912; heap="$heap --heap-limit 5368709120";
           compiler $c --pass-stats $args -o "$out/$p.$c.rbc" 2> "$out/$p.$c.stats.$i" > /dev/null)
        else
          compiler $c --pass-stats $args -o "$out/$p.$c.rbc" 2> "$out/$p.$c.stats.$i" > /dev/null
        fi ||
          { echo "perf-units: $c failed on $p" >&2; cat "$out/$p.$c.stats.$i" >&2; exit 1; }
        t1=$(now)
        ms=$(( (t1 - t0) / 1000000 ))
        if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best=$ms; cp "$out/$p.$c.stats.$i" "$out/$p.$c.stats"; fi
        i=$((i + 1))
      done
      echo "$c $p wall $best" >> "$out/phases.txt"
      sed "s/^/$c $p /" "$out/$p.$c.stats" >> "$out/phases.txt"
      awk -v c="$c" -v p="$p" -v wall="$best" -v lines="$lines" '
        /^pass / { name = $2; sub(":", "", name); t[name] += $(NF - 1) }
        END {
          fe = t["parse"] + t["elaborate"]
          printf "| %s | %s | %.3f |", c, p, wall / 1000
          n = split("parse elaborate translate mid shake lift workers simplify lower registers", k, " ")
          for (i = 1; i <= n; i++) printf " %.3f |", t[k[i]]
          printf " %d | %s |\n", lines, (fe > 0 ? sprintf("%.0f", lines / fe) : "-")
        }' "$out/$p.$c.stats"
    done
  done
}

mid() {
  # shellcheck disable=SC2086
  compiler mlton --dump-after=mid $boot_srcs -o "$out/compiler.rbc" > "$out/compiler.mid.raw"
  sed '1{/^(\* after mid \*)$/d}' "$out/compiler.mid.raw" > "$out/compiler.mid"
  echo "| Compiler | parse + elaborate + translate + mid of the sources | --read-mid of their Mid ($(wc -c < "$out/compiler.mid") bytes) |"
  echo "|---|---:|---:|"
  for c in $(echo "$configs" | tr ',' ' '); do
    # shellcheck disable=SC2086
    src=$(compiler $c --pass-stats $boot_srcs -o "$out/compiler.$c.rbc" 2>&1 >/dev/null |
          awk '/^pass (parse|elaborate|translate|mid):/ { t += $(NF - 1) } END { printf "%.3f", t }')
    rd=$(compiler $c --pass-stats --read-mid "$out/compiler.mid" 2>&1 >/dev/null |
         awk '/^pass mid:/ { t += $(NF - 1) } END { printf "%.3f", t }')
    echo "| $c | $src | $rd |"
  done
}

globals() {
  echo "| globals | minor collections | their processor time, ms | per minor collection, us | its roots besides the stack |"
  echo "|---:|---:|---:|---:|---:|"
  for n in 0 1000 10000 50000 100000; do
    f=$out/globals$n.sml
    {
      i=0
      while [ $i -lt $n ]; do echo "val g$i = ref $i"; i=$((i + 1)); done
      cat <<'EOF2'
fun build (0, acc) = acc | build (k, acc) = build (k - 1, k :: acc)
fun loop (0, s) = s | loop (k, s) = loop (k - 1, s + List.length (build (1000, [])))
val () = print (Int.toString (loop (16000, 0)) ^ "\n")
EOF2
    } > "$f"
    # -O0: no Shake, so every global is kept, as a REPL session keeps them
    bin/rune-mlton -O0 "$f" -o "$out/globals$n.rbc"
    best=""
    i=0
    while [ $i -lt "$runs" ]; do
      bin/runevm --gc-log "$out/globals$n.log" "$out/globals$n.rbc" > /dev/null
      ns=$(awk '$2 == "minor" { t += $23 } END { print t + 0 }' "$out/globals$n.log")
      if [ -z "$best" ] || [ "$ns" -lt "$best" ]; then best=$ns; cp "$out/globals$n.log" "$out/globals$n.best"; fi
      i=$((i + 1))
    done
    awk -v n=$n -v ns="$best" '
      $2 == "minor" { m++; roots = $16 }
      END { printf "| %d | %d | %.1f | %.1f | %d |\n", n, m, ns / 1e6, (m > 0 ? ns / m / 1000 : 0), roots }' \
      "$out/globals$n.best"
  done
}

for part in $parts; do
  echo
  echo "### $part"
  echo
  $part
done
