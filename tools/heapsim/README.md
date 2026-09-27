# tools/heapsim: the trace-driven heap simulator

`bin/heapsim` (`make heapsim`, from `sim.c`) replays a census trace
(`docs/census.md`; `scripts/census.sh WORKLOAD` makes one under
`tests/out/census/WORKLOAD`) under a candidate layout's size model
(`vm/layouts.h`, shared with the census VM and the harness of
`tests/layouts` so that the three cannot disagree) and a collector model,
and prints one tab-separated row (`bin/heapsim --header` names the
columns): bytes allocated, the boxes the layout adds and for what, bytes
copied, collections, the largest heap, the remembered set and the survival
per nursery size. The collector models are the two-space copier with
`vm/heap.c`'s policy transcribed, a nursery of a given size with promotion
at the first or the second survival into that copier and its remembered
set from the trace's stores, sticky mark bits (a non-moving old space,
fragmentation not modelled), a large-object space at a threshold, and
mutable objects segregated. Liveness between two of the census's forced
collections is known only as a band, and every number that depends on it
is given for `--band lo` and `--band hi`. This is how the tables of
`docs/plans/heap-layout.md`, *The experiments*, were made.

* `bin/heapsim-gen` (`gen.c`) writes a synthetic trace with exact
  liveness and computes what the stock collector would do on it, so that
  the simulator can be checked against an independent implementation:
  `test.sh` does, on three seeds and three sample intervals, and then
  runs every collector and layout once. Part of `make check-heapsim`.
* `validate.sh WORKLOAD...` holds the copier model to the stock VM: the
  workload runs on `bin/runevm-new --jit=off --stats` at five heap
  settings, exactly as `scripts/census.sh` ran it, and the lower band's
  collections and semispace must equal the stock's, with the stock's
  bytes copied and live data inside the band. `make
  check-heapsim` runs it on compile-sigs and intinf_fact; the roadmap ran
  it on 65 rows (`sim-validation.md` of *The experiments*).
* `sweep.sh WORKLOAD...` runs the whole matrix on a trace (layouts,
  variants, collectors, sizes, bands) into
  `tests/out/heapsim/sweep-WORKLOAD.tsv`, `--reduced` the short matrix the
  large MLton traces got; `report.py [DIR]` (Python 3, for the tables
  only) turns the sweeps of a directory into the Markdown tables of the
  roadmap, one file per question (`sim-heap-bytes.md`, `sim-copied-64M.md`,
  `sim-survival.md`, `sim-remset.md`, ...).

To reproduce the roadmap's simulator tables: `scripts/census.sh` on every
workload of *The workloads* (the bootstrap, compile-sigs, compile-hello,
runedoc-ir, runedoc-page, the eight programs of tests/perf, and
`mlton-NAME` for the MLton benchmarks at the sizes of
`tests/perf/mlton-bench.txt`), `tools/heapsim/sweep.sh` on each, then
`python3 tools/heapsim/report.py tests/out/heapsim`.
