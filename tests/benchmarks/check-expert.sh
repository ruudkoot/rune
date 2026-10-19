#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
mkdir -p "$root/tests/out/benchmarks"
out=$(mktemp -d "$root/tests/out/benchmarks/expert-checks.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/input.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/stream.sml examples/benchmarks/shared/nofib-expert-table.sml examples/benchmarks/shared/nofib-expert-phrase.sml examples/benchmarks/shared/nofib-expert-program.sml examples/benchmarks/shared/nofib-expert-driver.sml tests/benchmarks/expert-tests.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources.txt"
python3 - <<'DATA' > "$out/data.txt"
from pathlib import Path
base=Path("tests/benchmarks/data/expert")
for file in sorted(base.rglob("*")):
    if file.is_file() and file.name != ".gitattributes":
        print(file.relative_to(base))
DATA
status=0
for level in 0 2; do
  RUNE_MATRIX_RUN="$out/worker-O$level" RUNE_BENCH_COMPILE_OPTIONS=-O$level RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=1048576 \
    sh tests/basis/run-matrix.sh --configs "${BENCH_CONFIGS:-rune,rune:new,rune:jit,rune:opt,hosts}" \
      --program-list "$out/sources.txt" --program-data "$root/tests/benchmarks/data/expert" \
      --program-data-list "$out/data.txt" --program-out "$out/O$level" < /dev/null > "$out/O$level.log" 2>&1 || { cat "$out/O$level.log"; status=1; }
done
if [ "$status" != 0 ]; then echo "bench-expert: validation failures ($out)" >&2; exit 1; fi
echo "bench-expert: original dialogs, lazy feedback tables, unification and answer demand hold ($out)"
