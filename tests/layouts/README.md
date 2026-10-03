# tests/layouts: the layout harness

One C program, the same kernels compiled once per candidate layout, each
with a Cheney copier of its own: what a native or JIT-compiled program
would pay, in the mutator and in the collector, under each layout of
`docs/plans/heap-layout.md`. `make -C tests/layouts` builds the twenty
configurations of the `Makefile` into `tests/out/layouts/<cc>/harness-NAME`
(`CC=clang-18` for a second compiler); `make check-layouts` at the top
builds them with the tree's compiler and runs `check.sh`, which requires
every kernel's checksum to be the same under every layout, at a small
semispace (many collections: the rooting is tested) and at the default
one. Part of `make check`.

* `layouts/iface.h` is the interface a kernel is written against: values,
  immediates, boxing, allocation, field access (the barrier hook), pairs,
  constructor tags, closures, polymorphic equality, the root stacks.
  `layouts/L0.h` is today's 16-byte cell with the 8-byte header; `L1.h`
  the tagged 8-byte word (63-bit immediates, reals boxed), `L2.h` the same
  with 64-bit ints boxed above 63 bits, `L3.h` NaN-boxing, `L4.h` the
  untagged type-directed word; `objs8.h` the 8-byte-header objects the
  8-byte layouts share, `gc_core.h` the copier, and the variants are
  compile-time flags (`PAIRS` headerless pairs, `HDR4`, `ALIGN16`,
  `REALIMM` Koka's immediate reals, `FLATREAL`, `COMPACTBYTES`,
  `BARRIER_CARD`, `L4_MONO`/`L4_UNIFORM`, `L1_UNBOXED_LOCALS`). The size
  models are `runtime/census/layouts.h`, shared with the census VM and the simulator.
* `kernels.c` holds the kernels, SML-shaped: list building, the compiler's
  ordered map on ints and on strings, its int table of refs, closures,
  integer and word loops, reals in registers and in arrays, strings,
  structural equality, and a churn of short-lived data under a live tree.
  Each prints `kernel n checksum cycles gc_cycles gc_share`; `harness micro`
  times the primitive operations alone.
* `measure.sh` runs every configuration under `perf stat` (five runs, the
  least cycles, reruns when the spread exceeds 5%, waits for an idle
  machine) into `tests/out/layouts/harness-raw.tsv`; `micro.sh` the
  primitive operations into `harness-micro.tsv`; `tables.py [DIR]`
  (Python 3, for the tables only) makes the roadmap's tables from them:
  cycles, instructions and L1d misses relative to L0, the collector's
  share, the raw counters and the micro-benchmark.

The roadmap's numbers were made with gcc-13 and clang-18 on an idle
Haswell, pinned to one core; a change under 15% in cycles is within the
noise this machine produces and is not a conclusion.
