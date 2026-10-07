# tools/heapsim: the trace-driven heap simulators

Two simulators replay a census trace (`docs/census.md`, format 2;
`scripts/census.sh WORKLOAD` makes one under `tests/out/census/WORKLOAD`):
`bin/heapsim`, the heap-layout roadmap's, and `bin/gcsim`, the
second-generation collector's. Both place the objects, the samples and the
stores by the trace's own sizes (`w8_obj_size` of
`runtime/census/layouts.h`, shared with the census VM and the harness of
`tests/layouts` so that they cannot disagree), and both know liveness
between two of the census's forced collections only as a band: every
number that depends on it is given for `--band lo` (everything that dies
before the next sample is dead) and `--band hi` (everything that died since
the last sample is alive). At a sample liveness is exact. `make heapsim`
builds both and `bin/heapsim-gen`; `make check-heapsim` and `make
check-gcsim`, both part of `make check`, test them.

The tools write under `tests/out/heapsim` (heapsim's) and
`tests/out/gcsim` (gcsim's) unless given `--out DIR`, and take the
traces as arguments: a trace made elsewhere is named by its directory. A
run of either simulator holds the trace's per-object arrays in memory,
up to 26 bytes an object for gcsim and 33 for heapsim (900 MB and 1.1 GB
on the bootstrap's 34 million objects): run it under `ulimit -v`, as the
scripts do.

## heapsim: layouts and the first collectors

`bin/heapsim` (`sim.c`) replays a trace under a size model and a collector
model, and prints one tab-separated row (`bin/heapsim --header` names the
columns): bytes allocated, the boxes the layout adds and for what, bytes
copied, collections, the largest heap, the remembered set and the survival
per nursery size. `--layout W8`, the default, is today's layout, the
trace's own sizes; `L0` to `L4` are the heap-layout study's candidates
over the same trace, under which the word's boxes take no room of their own
and a field is boxed, or not, by the layout's rule. The collector models
are the two-space copier with `runtime/heap.c`'s policy transcribed, a
nursery of a given size with promotion at the first or the second survival
into that copier and its remembered set from the trace's stores, sticky
mark bits (a non-moving old space, fragmentation not modelled), a
large-object space at a threshold, and mutable objects segregated. This is
how the tables of `docs/plans/heap-layout.md`, *The experiments*, were
made, on the traces of format 1. `--check` holds death.bin and the sizes to
the census's live bytes at every sample.

* `bin/heapsim-gen` (`gen.c`) writes a synthetic trace of format 2 with
  exact liveness and computes what the stock collector would do on it, so
  that the simulator can be checked against an independent implementation:
  `test.sh` does, on three seeds and three sample intervals, and then runs
  every collector and layout once. `--pattern alt|satb|line1|nurs` writes
  the traces of gcsim's closed-form tests. Part of `make check-heapsim`
  (7 seconds).
* `validate.sh [--out DIR] WORKLOAD...` holds the copier model to the stock
  VM: the workload runs on `bin/runevm --jit=off --stats` at five heap
  settings, exactly as `scripts/census.sh` ran it, and the lower band's
  collections and semispace must equal the stock's, with the stock's bytes
  copied (with half the band's width as slack) and live data inside the
  band. The trace is made when it is missing or older than the bytecode or
  either VM; `CENSUS_TRACES` names the traces' directory and `CENSUS_EVERY`
  the interval of a census made here. `make check-heapsim` runs it on
  compile-sigs and intinf_fact; on the bootstrap at 32 KiB all five
  settings agree, the copied bytes within 0.1%.
* `checktrace.py DIR` and `checkold.py DIR` (Python 3 with numpy) check a
  trace's consistency and its stores' old values (`docs/census.md`,
  *Checks*).
* `sweep.sh WORKLOAD...` runs the heap-layout study's whole matrix on a
  trace (layouts, variants, collectors, sizes, bands) into
  `tests/out/heapsim/sweep-WORKLOAD.tsv`, `--reduced` the short matrix the
  large MLton traces got; `report.py [DIR]` turns the sweeps of a
  directory into the Markdown tables of that roadmap, one file per question
  (`sim-heap-bytes.md`, `sim-copied-64M.md`, `sim-survival.md`,
  `sim-remset.md`, ...).

## gcsim: the second generation's simulator

`bin/gcsim` (`gcsim.c`; `docs/plans/garbage-collector-v2.md`, *The
simulator*) replays a trace through a nursery and an old space whose
objects have addresses, and prints one row (`--header` names the columns;
`--help` lists every option). It reads the whole of format 2: the sizes
from alloc.bin, the instruction clock, the stack's depth, the frames, the
pointer slots and the stack watermark at every sample, and the old value
of every store. `--size W4` sizes the objects with a 4-byte word and header
(the 32-bit rows) and `L0` with 16-byte cells; `--ptr 4` counts
pointer-sized metadata at 4 bytes.

* **Liveness.** death.bin's window of death D; at a point in window k an
  object is dead when D < k (at a sample, exact), or D <= k under `--band
  lo` strictly inside a window; `--band near` takes the nearer sample's
  side. A collection that falls on a sample is exact in both bands. The
  models see no graph: reachable = alive in the census, so nepotism (dead
  old objects keeping young ones alive through the remembered set) and the
  order a traversal visits objects in are not modelled.
* **The nursery** (`--nursery N`, `--promote 1|2`, `--big T`): a minor
  collection where the next object does not fit (allocation order, trace
  sizes); objects above T (default N/4) go straight to old space; promotion
  at the first survival, or the second through a survivor space.
  Remembered slots (deduplicated by slot) and 512-byte cards at the old
  objects' real addresses: old-to-young stores, any pointer store, any
  store. Objects placed directly in old space are remembered at birth.
  `--mutable-space`: refs and arrays in a space every minor scans whole,
  with no barrier.
* **Old spaces** (`--old`): `copy` (`runtime/heap.c`'s two spaces, its sizing
  and survivor guess; with a nursery `--full appel` is the roadmap's
  prototype: a full collection over both spaces when old space has less
  room than the nursery holds, sized for what is needed and N); `mc` (one
  heap, Lisp-2 sliding or `--jonkers`, every major compacts in order);
  `mlton` (MLton's choice of copying or Jonkers by sizeofHeapDesired
  against `--limit`); `immix` (blocks `--block`, lines `--line`,
  conservative marking or `--exact-lines`, recyclable blocks, overflow
  allocation, opportunistic evacuation within `--headroom`, the candidates
  chosen by exact liveness: a best case); `sticky-immix` (no copying
  nursery: every object into free lines, sticky minors every N bytes);
  `segfit` (OCaml 5's size classes in 32 KiB pools); `bestfit`, `nextfit`,
  `firstfit` (OCaml 4's free lists with coalescing, 15% chunks, compaction
  when free/live >= `--max-overhead`%); `chez` (segments marked in place
  when never marked or >= `--dense` full at their last marking, copied
  otherwise). A large-object space (page-rounded, never moved) above
  `--los` (default 8K for immix and chez, 1025 bytes for segfit, none
  otherwise).
* **Policy.** Without a limit a non-moving old generation collects at
  live x 100 / `--heap-fill` of occupancy and commits what it needs
  (fragmentation shows as footprint); with `--limit B` or `--limit-x F`
  (F x the trace's most live) it collects when an allocation would commit
  past the limit and overflows (counted) when a major freed too little.
* **SATB** (`--satb K --satb-start THETA [--slice B]`): a cycle starts at
  THETA x the stop-the-world trigger's occupancy, marks K bytes per byte
  allocated (in each minor's pause, or every B bytes), allocates black,
  sweeps the snapshot's dead lazily at its end; floating garbage, duty,
  the SATB log (stores whose old value is a pointer, and of them to old
  objects older than the snapshot).
* **Pretenuring** (`--learn FILE [--learn-until F]`, `--pretenure FILE
  --pretenure-x X [--pretenure-from F]`); **image space** shares (marked
  bytes born in the first 1/5/10/25% of the run, `--phase`); **placement
  order** (`--shuffle SEED`, `--order bfs|dfs` over graph.bin).
* **Output.** The row; `--events FILE` one line per collection (the
  instruction clock, stack, roots, cards, remset, copied, promoted,
  marked, swept, moved and evacuated counts, live, committed, reserved and
  metadata bytes, held, usable and whole bytes); `--ops FILE` the old
  space's placements and frees, for an independent replay of the
  allocators (tests/gcbench's). `--check` holds death.bin and the sizes to
  the census's live bytes at every sample. `--max-mb M` (default 4096)
  caps the run's address space (setrlimit): past it the run stops with a
  message instead of taking the machine's memory.

The op stream of `--ops FILE` is text, one operation a line, after a
first line `# gcsim ops WORKLOAD old=MODEL size=W8`: `a ID SIZE ADDR
WHERE` (object ID of SIZE bytes placed at ADDR, in 8-byte granules within
its space, WHERE 3 the old space, 4 the LOS, 5 the mutable space), `f ID`
(freed: it died before the major that sweeps it; a major's frees come
together, in the order of their windows of death) and `m ID SIZE ADDR
WHERE` (moved: compaction, copying, evacuation). The sequence depends on
the model only through when majors happen; `--major-every B` adds a major
every B bytes, for a schedule an allocator replaying the stream can share.
With a nursery the placements are its survivors in promotion order. The
same stream should give an independent allocator of the same policy the
same committed bytes after each major as `--events`' `old_committed`,
within its rounding.

Its tests and the tools that made the roadmap's tables:

* `test2.sh` (`make check-gcsim`, 2 seconds): 94 checks, the closed-form
  patterns of `heapsim-gen --pattern` (alternate deaths leave exactly half
  the slots or lines free, one survivor a line frees no line, compaction
  moves exactly the live bytes, snapshot marking floats exactly the objects
  that die during the cycle, promotion, the remembered set and the cards at
  real addresses) and the identities with `bin/heapsim`'s copier, nursery
  and sticky models on gen.c's random traces, in both bands.
* `sweep2.sh [-P N] [--plan full|reduced] [--only Q] [--out DIR] TRACE...`:
  the sweeps, one question at a time (nursery, old spaces at equal memory,
  fragmentation, the mutable space, SATB, placement order, 32-bit,
  events) into `DIR/sweep/QUESTION/NAME.tsv` and the events into
  `DIR/events`; `--plan reduced` for large traces. On compile-sigs the
  reduced plan takes 6 seconds.
* `report2.py SWEEPDIR OUTDIR [TRACE...]`: the Markdown tables of the
  sweeps, one file per question (`sim-survival.md`, `sim-nursery.md`,
  `sim-remset.md`, `sim-oldspaces.md`, `sim-fragmentation.md`,
  `sim-image.md`, `sim-mutable.md`, `sim-satb.md`, `sim-order.md`,
  `sim-footprint.md`), with modelled GC times from `timeline.py`'s
  coefficients.
* `timeline.py [--coef FILE] [--tier T] [--lazy-sweep] [--watermark] EVENTS...`:
  pauses, percentiles, a histogram, the minimum mutator utilisation at 1
  to 200 ms and the footprint from `--events`, with a linear cost model
  whose coefficients are the unit costs `tests/gcbench` measured where they
  apply and placeholders (named in `PLACEHOLDERS`) where not; `--gclog`
  reads a VM's `--gc-log` (`docs/runtime.md`) instead, its measured pauses
  on its instruction clock.
* `pauses.py EVENTSDIR VALIDATEDIR OUT.md [TRACE...]`: the pause and MMU
  table of the events question, at the default tier and the interpreter's,
  and the stock copier's measured pauses from `validate2.sh`'s logs beside
  the model's.
* `validate2.sh [--vm VM] [--out DIR] [--settings "H:F ..."] TRACE...`:
  `validate.sh` for gcsim's copier, with the clock of every collection:
  the stock VM (`bin/runevm`, its `--gc-log`) runs the trace's own command
  at five heap settings; ok when the lower band's collections and
  semispace are the stock's and the copied bytes lie in the band (half its
  width as slack), band when the stock lies between the bands.
* `validate-proto.sh --vm VM [--out DIR] [--nurseries "N ..."] TRACE...`:
  gcsim's nursery and copying old space (`--full appel`) against a VM with
  a nursery that takes `--nursery N` and writes `--gc-log` with minor and
  full lines (the roadmap's prototype, until its M3 builds the nursery):
  the minors and full collections must agree and the promoted bytes lie in
  the band (above it is nepotism).
* `pretenure.sh [--out DIR] LEARN-TRACE APPLY-TRACE [NURSERY] [OLD]`:
  pretenuring by allocation site, learned on one run (or its first half)
  and applied to another (or the second half) at 50, 80 and 95% survival.
* `report3.py LOGDIR OUTDIR`: `sim-validation.md` and `sim-pretenure.md`
  from the outputs of `test2.sh`, `gcsim --check`, `validate2.sh`,
  `validate-proto.sh` (kept as `*.log` or `*.txt` in LOGDIR) and
  `pretenure.sh --out LOGDIR`.

To reproduce the roadmap's simulator tables: `scripts/census.sh --graph`
on every workload of its *The workloads* (the bootstrap at 32 KiB,
compile-sigs, runedoc-page, the programs of tests/perf, the lazy programs
and `mlton-NAME` for MLton's benchmarks at the sizes of
`tests/perf/mlton-bench.txt`), then on each trace `bin/gcsim --check`,
`tools/heapsim/sweep2.sh` (`--plan reduced` for the MLton programs) and
`validate2.sh`, `pretenure.sh` on the compiler's traces, and
`report2.py tests/out/gcsim/sweep OUT`, `pauses.py tests/out/gcsim/events
tests/out/gcsim/validate OUT/sim-pauses.md` and `report3.py
tests/out/gcsim OUT`. The traces of the experiments (2026-10-05 and 06)
are 20 GB.
