#!/bin/sh
set -eu
root=$(pwd)
p="$root/tests/out/benchmarks/nofib-happy-originals"
for source in examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/suspend.sml examples/benchmarks/shared/hartel-ida-finite.sml examples/benchmarks/shared/happy-set.sml examples/benchmarks/shared/happy-lexer.sml examples/benchmarks/shared/happy-kernel.sml; do
 printf '%s\n' "$root/$source"
done > "$p/nj32-probe-sources.txt"
printf '%s\n' "$p/nj32-reference-probe.sml" >> "$p/nj32-probe-sources.txt"
RUNE_MATRIX_RUN="$p/nj32-probe-worker" RUNE_MATRIX_TIMEOUT=600 RUNE_MATRIX_MEMORY=4194304 sh tests/basis/run-matrix.sh --configs native:smlnj32 --program-list "$p/nj32-probe-sources.txt" --program-out "$p/nj32-probe-matrix" < /dev/null > "$p/nj32-probe.log" 2>&1
