# Minimax custom-player checks on ML Kit

Tested the managed ML Kit 4.7.23 at its default options. Native host invocations
in the O0/O2 auxiliary batches use the same host defaults; those labels describe
Rune compilation levels, not two ML Kit optimization settings.

All 56 primary minimax smoke/normal cases pass, including ML Kit's separate
lazy and strict benchmark programs. All eight normal count samples agree on
Rune. The auxiliary suite instead instantiates both policies and supplies
custom player functions to a three-node tree.

In each auxiliary invocation ML Kit passes 90 assertions, then exits 255 with
an allocation error during the strict custom-player recursive fold. Six
assertions are unreached in each invocation. The other eighteen invocations
pass all 96 assertions: 1908 assertions pass overall, none reports a failed
assertion, and twelve are unreached. Both failing processes have a 1-GiB
address-space cap. This is recorded as a runtime failure with an allocation
error under the cap; reaching a resident-memory limit is not established.

The failing test has only a root and two leaves, with expected result Score 1.
The first player returns its first argument; the second returns its second
argument. Strict right-fold evaluation calls the first twice and the second
once. Rune and MLton reproduce that result and call counts.

[The isolated probe](../../../../rune-benchmark-results/m3-minimax/host-diagnostics/strict-only-probe.sml)
reproduces the allocation error with the full minimax functor, one strict
instantiation and a 256-MiB cap. It requires no game search, input file or prior
auxiliary checks. A version without the counters also fails. A plain three-node
fold without the delay functor passes, as does a smaller delay-functor fold,
including both lazy and strict instantiations. These controls narrow the
context but do not identify a compiler/runtime cause.

The imported kernel and valid custom-player check are retained. No source
rewrite or increased cap is used to turn this diagnostic into a pass. The
complete [semantic ledger](../../../../rune-benchmark-results/m3-minimax/semantic-summary.tsv), logs and
probe sources retain the failure and control scopes. No updated ML Kit build
was tested and no upstream issue was posted.

To repeat the strict-only probe from the repository root:

~~~sh
mkdir -p tests/out/benchmarks/mlkit-minimax-repro
for source in tests/basis/harness.sml \
  examples/benchmarks/shared/lazy.sml \
  examples/benchmarks/shared/suspend.sml \
  examples/benchmarks/shared/nofib-minimax.sml \
  [examples/benchmarks/results/m3-minimax/host-diagnostics/strict-only-probe.sml](../../../../rune-benchmark-results/m3-minimax/host-diagnostics/strict-only-probe.sml) \
  tests/basis/finish.sml; do
  printf '%s/%s\n' "$PWD" "$source"
done > tests/out/benchmarks/mlkit-minimax-repro/sources.txt
RUNE_MATRIX_RUN="$PWD/tests/out/benchmarks/mlkit-minimax-repro/worker" \
RUNE_MATRIX_TIMEOUT=30 RUNE_MATRIX_MEMORY=262144 \
  sh tests/basis/run-matrix.sh --configs rune,native:mlton,native:mlkit \
  --program-list "$PWD/tests/out/benchmarks/mlkit-minimax-repro/sources.txt" \
  --program-out "$PWD/tests/out/benchmarks/mlkit-minimax-repro/result"
~~~
