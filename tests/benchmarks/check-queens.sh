#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
root=$(pwd)
out=$(mktemp -d "$root/tests/out/benchmarks/queens-tests.XXXXXX")
for source in tests/basis/harness.sml examples/benchmarks/shared/lazy.sml examples/benchmarks/shared/queens.sml tests/benchmarks/queens.sml tests/basis/finish.sml; do
  printf '%s\n' "$root/$source"
done > "$out/sources"
sh tests/basis/run-matrix.sh --configs rune,native:mlton,native:smlnj-legacy,native:polyml --program-list "$out/sources" --program-out "$out/matrix" < /dev/null > "$out/result.log" 2>&1
[ "$(grep -c '^PROGRAM PASS ' "$out/result.log")" = 4 ] || { cat "$out/result.log"; exit 1; }
echo 'bench-queens: lazy demand, memoized values/exceptions, reentry and ten board sizes passed on four compilers'
