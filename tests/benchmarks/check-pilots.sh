#!/bin/sh
# Independent result checks and failure propagation through the matrix loader.
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
out=$root/tests/out/benchmarks/validation
mkdir -p "$out"
{
  for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/primes.sml examples/benchmarks/bdd/benchmark.sml tests/benchmarks/semantics.sml tests/basis/finish.sml; do
    printf '%s\n' "$root/$source"
  done
} > "$out/semantics.sources"
RUNE_MATRIX_TIMEOUT=120 RUNE_MATRIX_MEMORY=4194304 sh tests/basis/run-matrix.sh \
  --configs rune,hosts --program-list "$out/semantics.sources" --program-out "$out/semantics" < /dev/null > "$out/semantics.log" 2>&1
[ "$(grep -c '^PROGRAM PASS ' "$out/semantics.log")" = 7 ] || { cat "$out/semantics.log"; exit 1; }
echo 'bench-semantics: OK (90 checks on each of seven configurations)'

expect_failure() {
  label=$1; seconds=$2; memory=$3; sources=$4; input=$5
  if RUNE_MATRIX_TIMEOUT=$seconds RUNE_MATRIX_MEMORY=$memory sh tests/basis/run-matrix.sh \
    --configs rune --program-list "$sources" --program-input "$input" --program-out "$out/$label" < /dev/null > "$out/$label.log" 2>&1; then
    echo "negative test passed incorrectly: $label" >&2; exit 1
  fi
  grep -q '^PROGRAM FAIL ' "$out/$label.log" || { cat "$out/$label.log"; exit 1; }
}
{
  for source in shared/input.sml shared/tak.sml tak/benchmark.sml shared/main.sml; do printf '%s\n' "$root/examples/benchmarks/$source"; done
} > "$out/tak.sources"
printf 'tak\n18 12 6 1\n999\n' > "$out/wrong.input"
expect_failure wrong-result 30 1048576 "$out/tak.sources" "$out/wrong.input"
printf 'wrong-name\n18 12 6 1\n7\n' > "$out/name.input"
expect_failure wrong-name 30 1048576 "$out/tak.sources" "$out/name.input"
cat > "$out/false-success.sml" <<'SML'
structure FalseSuccess = struct
  val _ = print "PASS fake\nSUMMARY 1 checks, 0 failed\n"
  val _ = OS.Process.exit OS.Process.failure
end
SML
printf '%s\n' "$out/false-success.sml" > "$out/false.sources"
expect_failure false-success 30 1048576 "$out/false.sources" /dev/null
cat > "$out/loop.sml" <<'SML'
structure Forever = struct
  fun loop () : unit = loop ()
  val _ = loop ()
end
SML
printf '%s\n' "$out/loop.sml" > "$out/loop.sources"
expect_failure timeout 1 1048576 "$out/loop.sources" /dev/null
grep -q 'timed out' "$out/timeout.log"
cat > "$out/memory.sml" <<'SML'
structure MemoryPressure = struct
  val _ = print "START memory\n"
  val values = Array.array (100000000, 0)
  val _ = print (Int.toString (Array.length values))
end
SML
printf '%s\n' "$out/memory.sml" > "$out/memory.sources"
expect_failure memory 30 262144 "$out/memory.sources" /dev/null
grep -q 'START memory' "$out/memory.log"
cat > "$out/invalid.sml" <<'SML'
structure Invalid = struct val value : int = true end
SML
printf '%s\n' "$out/invalid.sml" > "$out/invalid.sources"
expect_failure compile-error 30 1048576 "$out/invalid.sources" /dev/null
if RUNE_MATRIX_TIMEOUT=30 RUNE_MATRIX_MEMORY=262144 sh tests/basis/run-matrix.sh \
  --configs native:polyml --program-list "$out/memory.sources" --program-out "$out/poly-memory" < /dev/null > "$out/poly-memory.log" 2>&1; then
  echo 'Poly/ML memory limit did not stop allocation' >&2; exit 1
fi
grep -q 'START memory' "$out/poly-memory.log"
grep -q '^PROGRAM FAIL ' "$out/poly-memory.log"
echo 'bench-negative: OK (wrong result, name mismatch, nonzero exit, timeout, memory limit, compile error)'
