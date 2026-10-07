# tests/gcbench: the collector harness

One C program, `tests/out/gcbench/gcbench`, with a subcommand for each
experiment of `docs/plans/garbage-collector-v2.md` (*The experiments*,
*The harness*, H1-H3 and H5-H10): what each unit of a collector's work
costs on the machine it runs on and how the caches change it, which are
the coefficients that turn the simulator's counts (objects and bytes
copied, marked and swept, slots and frames scanned, cards, pages) into
time. The mutator and the collector are counted apart, by counters read
inside the process.

    make gcbench              # tests/out/gcbench/gcbench, with the tree's CC
    make check-gcbench        # every experiment at tiny sizes, its self-checks on; part of make check
    tests/out/gcbench/gcbench SUBCOMMAND [NAME=VALUE ...] [check=1]     # one untimed run
    tests/gcbench/measure.sh NAME [-n RUNS] [-e "mem l2"] [-c CPU] [-m KiB] -- SUBCOMMAND [NAME=VALUE ...]
    tests/gcbench/roadmap.sh  # the runs that made the roadmap's tables; report.py writes them

It is for Linux on x86-64 (`perf_event_open`, `rdpmc`, `rdtscp`), built
with gcc or clang as one translation unit: `-std=c17 -O2 -Wall -Wextra
-pedantic` (the tree's `CFLAGS`) and `GCB_ARCH`, `-march=native` by
default, since the harness measures the machine it runs on (`GCB_ARCH=`
builds for any x86-64; `make -C tests/gcbench CC=clang-18` for another
compiler; a change of either rebuilds). `make check-gcbench` elsewhere
says so and does nothing.

## The experiments

A subcommand takes `NAME=VALUE` options (numbers may end in K, M or G,
lists are comma-separated); every experiment has `reps=` (the repetitions
in a process) and `check=1`. Its rows go to standard output, a comment
line for each configuration (survival, slow paths, checksums) to standard
error. Each source file's opening comment says what it does in detail.

| Subcommand | What it measures | Options (defaults) |
|---|---|---|
| `h1` | The nursery's size against L1, L2 and L3: objects with the sizes and lifetimes of a census trace, each dying at a clock in the interval its death lies in, kept alive by reachability (a chain per 4 KiB of death clock); a nursery of each size and a Cheney minor into an old space. The mutator and the minors per KiB allocated; survival on stderr. `pf=256` adds prefetchw ahead of the bump pointer; `huge=1` puts the nursery in transparent huge pages. | `trace=` (required), `bytes=512M`, `nursery=64K,...,32M`, `pf=0,256`, `band=lo` (or `mid`, `hi`), `huge=0`, `reps=3` |
| `h2` | Copying and marking per object and per byte: `heapgen.h`'s heaps (a list, a binary tree, a chain with random edges, arrays of pointers) of 16 to 256-byte objects, in creation order or shuffled, traced by `collect.h`: a Cheney copy as `runtime/heap.c`'s, with and without prefetch, and marking by a header bit or a side bitmap, enqueuing nodes or edges (a prefetching FIFO). A repetition traces 8 MiB at least. | `gc=copy,...`, `shape=list,tree,graph,array`, `size=16,...,256`, `live=32K,1M` (128M: far past the caches, `reps_big=3`), `order=alloc,shuf`, `reps=5` |
| `h3` | Mark bits in the header against a side bitmap (H3 and H4): clearing the marks (a header walk, the bitmap, Immix's line marks), sweeping (by headers into a free list, by the bitmap, by line marks, by a bitmap a pool, into free lists), and allocating after a sweep, eagerly, lazily or from the bitmap. Per object of the heap, or per allocation. | `heap=1M,128M`, `size=16,32,64`, `live=0.1,0.5,0.9`, `runs=0` (1: marks in runs of 16), `what=...`, `reps=5` |
| `h5` | `alloc.h`'s old-space allocators (bump with sliding, Immix, OCaml 5's segregated fit, OCaml 4's best fit, first fit, next fit) replaying a census trace's promotions: a minor at every N/every-th sample, where liveness is exact, a major at FACTOR times what lived after the last; the allocator's work per object, the fragmentation after each major (`# H5-frag` lines, and into `frag=FILE`), and a traversal of what lives at the end (through `graph.bin`). `ops=FILE` replays the simulator's old-space stream instead (`gcsim --ops`). | `trace=` or `ops=` (one required), `alloc=...`, `nursery=1M`, `factor=2`, `min=4M`, `line=128`, `exact=0`, `graph=1`, `reserve=1G`, `bytes=`, `frag=`, `majors=`, `reps=3` |
| `h6` | Write barriers (`gen.h`): none, a masked card mark (`RUNE_BARRIER_CARDS`), a card only for a young value, a store buffer with a side byte or the header's remembered bit, Dart's combined test, a snapshot barrier with marking off and on, each inlined into four kernels (`h6k.h`: the int table of refs, an imp-for nest of refs, the update of old thunks, an accumulator in a ref). The mutator and the minors per store; slow paths and what the minors scanned on stderr. | `kernel=inttable,impfor,lazyold,refcons`, `bar=none,...,satb-on`, `nursery=1M`, `old=256M`, `n_inttable=400K`, `n_impfor=10M`, `n_lazyold=2M`, `n_refcons=10M`, `reps=5` |
| `h7` | Placement order and the mutator after it: a functional map built by path copying and a list with garbage between its cells, laid out as allocated (holes), slid, by Cheney's breadth-first copy and depth first; lookups and walks of the map, a sum of the list. | `n=256K,1M`, `reps=5` |
| `h8` | The stack as roots: `runtime/heap.c`'s `stack_roots` over the VM's frames, with every slot a root (`all`), the liveness of `runtime/register/live.c`'s binary search (`live`), a global hash on the return pc (`hash`), and the binary search with a branch-free slot loop (`bits`). Per frame. | `frames=100,10K,1M`, `locals=4,16,64`, `rets=4,64,1024`, `funcs=1,64,4096`, `ptr=0.5`, `young=0.1`, `how=all,live,hash,bits`, `reps=5` |
| `h9` | Pages: first touch with 4 KiB and huge pages, mmap and munmap, malloc and free, `MADV_DONTNEED` and the fault after it, `MADV_FREE`. TSC time, per page or per call; page faults on stderr. | `block=32K,256K,1M,32M`, `touch=256M`, `reps=5` |
| `h10` | The baselines: the latency of a dependent load through a random cyclic chain over a buffer's lines, with 4 KiB and huge pages, and page by page (`latpg`, a TLB miss every 64 loads); the bandwidth of memcpy, memset and a sequential read. | `sizes=8K,...,1G`, `huge=both` (0, 1), `what=lat,bw` (and `latpg`), `reps=5` |
| `mktrace` | Writes a synthetic trace in the census's format (`alloc.bin`, `death.bin`, `samples.bin`, `graph.bin`, `meta.txt`) for `check.sh` and for trying H1 and H5 without the census; not a workload. | `dir=` (required), `objects=200K`, `every=32K`, `seed=1` |
| `alloc-test` | `alloc.h`'s allocators against their closed forms and a shadow heap (*The self-checks*). | `objects=40K`, `rounds=6`, `reserve=256M`, `seed=1` |

H1 and H5 read the census's traces of the word layout (format 2,
`docs/census.md`): `trace=DIR` is a path, `trace=NAME` a directory under
`$GCB_TRACES`.

## How it measures

* **The objects are `runtime/value.h`'s**: an 8-byte header (the kind
  with the collector's nibble above it, pad, contag, len), payloads
  rounded to 8, 16 bytes at least; values are the tagged word of
  `tests/layouts`' L1 (`tests/layouts/common.h` is included for the kinds
  and helpers). The copy loop is `runtime/heap.c`'s `copy_obj` (a
  fixed-size `memcpy` for one to six fields), the stack scan its
  `stack_roots`, the liveness lookup `runtime/register/live.c`'s
  `reg_frame_live`.
* **Counters in the process.** `gcb.h` opens `cycles:u`,
  `instructions:u` and four programmable events with `perf_event_open`,
  as one group, and reads them with `rdpmc` (about 35 cycles a counter on
  the reference machine, against some 2,000 for a `read`), so that a
  phase -- the mutator, a minor collection, a sweep -- is counted apart
  from what surrounds it. `GCB_EV` picks the four: `mem` (the default:
  L1D.REPLACEMENT, L2_RQSTS.MISS, LONGEST_LAT_CACHE.MISS,
  DTLB_LOAD_MISSES.MISS_CAUSES_A_WALK), `l2` (L2 demand-read, RFO and
  prefetch misses, DTLB store walks), `br` (branch misses,
  L1D.REPLACEMENT, L2 demand-read misses, LLC misses) or `tlb` (load
  walks, walk cycles, store walks, STLB hits). The raw codes are
  Haswell's: another processor counts something else under them or does
  not open them. The counters count user mode only, so the kernel's share
  (page faults, `madvise`) shows in the TSC column and not in `cyc`.
* **Without counters** (no permission, as under Ubuntu's default
  `perf_event_paranoid`, a machine without a PMU, or `GCB_EV=none`) the
  harness says so on stderr and goes on with the TSC: `cyc` is TSC ticks,
  the other counters are zero and the event set column says `tsc`.
  Nothing else changes, and nothing needs `perf`.
* **Time** is the TSC's, read with `rdtscp`, its rate the first `cpu MHz`
  of `/proc/cpuinfo` (3192.6 MHz on the reference machine, whose TSC is
  invariant; a calibration against `CLOCK_MONOTONIC` wandered by 3% under
  WSL2). Where that line is the core's current clock instead, the `ns`
  column is approximate.
* **Repetitions.** Every measurement runs its work `reps` times and keeps
  the repetition with the fewest cycles, with the median beside it; a
  small one runs several rounds a repetition (8-16 MiB of work, or 16M
  loads) and counts only the timed phases (not the rebuild of a heap
  between copies, say).
* **`measure.sh`** makes a measurement: it waits for a 1-minute load
  below `LOADMAX` (1.5) and for `MemAvailable` of at least the `ulimit -v`
  (`-m`, 4 GiB) plus `SPARE` (8 GiB), pins the process to one core
  (`taskset -c 5`, `-c`), runs RUNS processes (`-n`, 5) for each event set
  (`-e`), reruns one when the load rose past twice `LOADMAX` meanwhile, and
  writes `tests/out/gcbench/NAME.raw.tsv` (every row), `NAME.tsv` (for each
  case the run with the fewest cycles, and the spread of the runs) and
  `NAME.log` (the command, the flags of the build, the loads, stderr, and
  `/usr/bin/time`'s user and system seconds, minor faults and peak resident
  set of each process). It runs a copy of the binary (`NAME.bin`). On a
  machine shared with other timed work, `GCB_LOCK` names a command that
  holds the machine's exclusive lock while it runs its arguments, and
  measure.sh runs itself under it (the roadmap's drafts had one:
  `GCB_LOCK="DRAFTS/lock.sh timed gcbench"`).
* **A row** is `exp case unit n cyc ins EV0..EV3 tsc ns cyc_med reps
  evset` (measure.sh adds `run` and `spread`): the counters per unit, of
  `n` units; `ns` is the TSC's time.

## The self-checks

`check=1` turns on what an experiment checks of itself, makes the work
that only steadies a timing (rounds within a repetition) happen once, and
makes the exit status 1 when a check failed; the rows of such a run are
not measurements. `check.sh` (`make check-gcbench`) runs every subcommand
so at tiny sizes, under `timeout` and `ulimit -v`, in a second or two;
nothing is timed, so it may run on a loaded machine, and one run is made
with `GCB_EV=none`. What is checked:

* H1: after every minor no root and nothing promoted since the last one
  points into the nursery, the old space parses, and every prefetch
  distance promotes the same bytes in the same minors.
* H2: every copy and mark reaches every object and byte of the heap, and
  after a copy every pointer of to-space is to the start of one of its
  objects.
* H3: the sweeps by headers and by the bitmap free the same bytes, the
  dead ones; the pool sweep threads, and every allocator finds, one slot
  for each dead object; clearing the header marks leaves none.
* H5: after every major and at the end every object of the old space
  holds its header and its id, no two overlap, the footprint covers them,
  and the live bytes are what the trace's sample says; the ops replay
  checks the same of what it placed. `alloc-test` checks the allocators
  without a trace: the closed forms (2N objects of 32 bytes, every other
  one dead, then one in every 128-byte line alive) and a shadow heap,
  rounds of allocations of 16 bytes to 20 KiB with every word written
  with the object's id and majors that kill a third to two thirds; after
  each, every live object still holds its id, none overlap, each lies in
  the reservation unless it is large, segfit's pools count them, and the
  free-list heaps parse, their free blocks what the allocator counts.
* H6: every barrier's kernel gives the checksum of a pass that counts the
  stores and scans the whole old space, and after every minor neither a
  root nor an old object points into the nursery (the barrier missed no
  store).
* H7: every layout holds the live bytes, and the map and the list give
  the same results on every layout.
* H8: the hash and the binary search give every return point the same
  mask; `all` finds every young pointer of the stack, and `live`, `hash`
  and `bits` the same roots and leave the same stack.
* H9: a page given back with `MADV_DONTNEED` reads as zeros.
* H10: the latency chain is one cycle through every line.

## How the roadmap's tables were made

The numbers of the roadmap's *The harness* are the drafts'
`results/gcbench-H*.md`, `results/gcbench-fragmentation.md` and
`results/coefficients.md` (where they are kept: the roadmap's *The
experiments*), made between 2026-10-05 19:30 and 2026-10-06 18:45 with
this harness before it came into the tree, built by gcc 13.3 with `-std=gnu17 -O2
-march=haswell`. `roadmap.sh` runs the same measurements under the same
names, in the same order: each table names its command, and every one ran
by `measure.sh`'s rules on the reference machine, at a 1-minute load of
0.7-1.4 at its start, the least of 3-5 processes, each the least of 3-5
repetitions. H1 and H5 replayed the census's traces (the bootstrap
sampled every 32 KiB, `compile-sigs`, `runedoc-page` and six of MLton's
benchmarks); H5's ops replay took the simulator's stream for the
bootstrap (`gcsim --nursery 1M --old segfit --major-every 16M --ops`).
`report.py [OUTDIR [RESULTSDIR]]` (Python 3) writes the tables from
`tests/out/gcbench/*.tsv` and the logs; the comparison with the simulator
in `gcbench-fragmentation.md`, and `coefficients.md`, were written by hand
from them, with the prototype's fitted coefficients beside them.

Three things differ from the harness the drafts ran, and a run now does
not reproduce the drafts' rows where they matter:

* H5 read a trace's sampling interval from `meta.txt` only if no line
  without a number came before it, and the census writes `layout W8`
  second, so it took 256 KiB for every trace: the drafts' H5 replays of
  the 32 KiB traces collected the nursery every N/8 bytes (`n=1M` was a
  minor every 128 KiB). The interval is read now. On `compile-sigs` at
  `n=1M min=1M` the promoted objects fall by 17% and segfit's peak
  footprint over peak occupancy from 1.20 to 1.08.
* H3's sweeps by headers and by the bitmap wrote a free list's link into
  an 8-byte free block, the tail of a pool, over the next object's
  header, for object sizes that leave such a tail (24, 40, 48 bytes); the
  drafts' rows are of 16, 32 and 64 bytes, which do not.
* The build is the tree's: strict C17, warning-free under gcc and clang,
  and `-march=native`, which on the Haswell is its own instruction set.

## The machine

The reference machine is a Xeon E5-1680 v3 (Haswell) under WSL2: L1d 32
KiB, L2 256 KiB, L3 20 MiB shared, 31 GB. What of it shows in the numbers
is its own, not the design's: the hypervisor backs the guest with 4 KiB
pages, so the second-level TLB reaches 4 MiB and huge pages in the guest
extend that only to about 7 MiB; a page touched for the first time costs a
hypervisor fault of 1.6 µs; the L3 is shared with the host, and one
thread's effective L3 for data walked in order is about 10-12 MiB;
MEM_LOAD_UOPS_RETIRED does not schedule more than two at a time under
Hyper-V and is not used. Instructions and misses are exact to a few
percent; cycles carry 10-15% of noise between runs, so a difference
smaller than that is not a conclusion. On another processor the raw
events mean something else: the instruction counts and the TSC are what
carry over.

## What it cannot represent

* The interpreter's and the JIT's own working set: every kernel here is a
  small C loop, so the caches hold the collector's data and little else.
  How the nursery's size meets the real mutator's working set is the
  prototype's sweep to decide, not H1's.
* Object graphs: H2's shapes are synthetic; H1 has no pointers between
  live objects but the chains that keep them alive (no nepotism, no
  old-to-young pointers); H5's traversal follows the trace's pointers at
  allocation time, not the program's reads.
* Liveness between a trace's samples (H1 `band`, H5 collects at samples).
* The cost of a barrier inside compiled code (H6's are C, inlined by gcc,
  not the JIT's or runeopt's code), and incremental marking itself (SATB's
  buffers are filled and dropped, never marked from).
