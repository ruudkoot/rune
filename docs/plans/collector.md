# Brief: the collector after the copier

A brief, not a roadmap: what the roadmap of the next collector is asked,
what is known, and what is in place. Written on 2026-10-04 as the last
piece of the heap layout's M7 (`heap-layout.md`), from that roadmap's
simulator and from the VM as M7 leaves it. Every number names where it
is from; none is an estimate unless it says so.

## What is asked

A roadmap, in the form of `jit.md` and `heap-layout.md`, for the
collector that comes after the Cheney copier: a generational one first
(`performance.md`'s item 13), with the owner's end state in sight
(`~/notes/virtual-machine.md`: many cores, no pause, millions of green
threads, isolated processes in one VM). It decides, on measurements it
makes itself:

1. whether a nursery pays for Rune's programs, and at what size;
2. what the old space is: copied, marked in place, or both by age;
3. the barrier's body and the remembered set;
4. how the heap grows and what a run costs in memory;
5. what is promised about pauses;
6. what of this a second thread changes.

## Where the copier stands

One Cheney two-space copier for every engine, stop-the-world, precise,
moving, with no barrier (`docs/runtime.md`, *The garbage collector*).
On the tagged 8-byte word, with a waiting frame's dead registers
dropped as roots (heap-layout M5 and M6), on the reference machine:

| | bootstrap | MLton's 33 |
|---|---:|---:|
| bytes allocated | 887 MB | 9,994 MB |
| collections | 10 (from 64 MiB; 18 from 4 MiB) | 1,954 |
| bytes copied | 306 MB (383 MB from 4 MiB) | 1,833 MB |
| the most a collection kept | 42 MB | |
| semispace at the end | 134 MB, so 268 MB held | |
| the collector's time | 0.39 s of 2.3 s | |
| the longest collection | 62 ms | `fft` 80 ms, `hamlet` 1.3 ms |

(`heap-layout.md`, *M5, done* and *M6, done*; `runevm --stats`, whose
last field is the longest collection since M7.)

* **The copier's cost is what is live, times the collections.** The
  compiler's long-lived data is copied ten times. That is the case for
  a generation.
* **The heap is sized by doubling**, until what survives is at most
  half of it. Measured at M7 with a finer step (`-DRUNE_HEAP_GROW=P`,
  P percent a step), the bootstrap:

  | growth | `--heap-fill` | collections | semispace | bytes copied |
  |---|---:|---:|---:|---:|
  | doubling | 50 | 10 | 134 MB | 306 MB |
  | doubling | 33 | 6 | 268 MB | 182 MB |
  | by 50% | 50 | 14 | 101 MB | 450 MB |
  | by 50% | 33 | 9 | 151 MB | 272 MB |
  | by 25% | 50 | 18 | 105 MB | 590 MB |
  | by 12% | 50 | 18 | 95 MB | 588 MB |

  A tighter heap is paid for with every byte that is live at every
  extra collection: a quarter less memory for nearly twice the copying.
  Doubling stays for the copier. The finer step belongs to an old space
  that is not copied at every collection, which is this roadmap's.

## What the simulator says

`tools/heapsim` on the traces of the census VM (`heap-layout.md`, *The
simulator*; the traces are of the 16-byte layout, with the word's
figures beside them where they were made).

* **Survival is high for a compiler.** Of what the bootstrap allocates,
  29.6% outlives a nursery of 256 KiB, 25.7% one of 1 MiB, 23.3% one of
  4 MiB (25.2%, 23.1% and 21.4% promoted if promotion waits for the
  second survival). `compile-sigs`: 30% at 256 KiB, 13% at 32 MiB. The
  programs of `tests/perf` are at 0%, and `list_ops`, which builds one
  list, at 74%.
* **At today's heap a nursery saves the bootstrap no copying.** A 1 MiB
  nursery promotes 267 MB, and its old space, run as the copier from
  4 MiB, copies another 172 MB in seven collections: 439 MB against
  the single copier's 324 MB from 64 MiB. At a tight heap it saves a
  great deal (the copier at 1.25 times the live data copies 2.44 GB).
  What it buys at any size is the memory (an old space that grows to
  fit 63 MB of live data against two semispaces of 256 MB) and the
  pauses.
* **Under the word the picture is the same, smaller:** survival at
  1 MiB 24.8% for 25.7%, 586 minor collections for 1,034, since 1.7
  times the objects fit a nursery; the remembered set grows with them,
  22,054 entries at its largest for 13,472.
* **The remembered set is small and the stores are few:** 13,472
  entries and 838 cards of 512 bytes at the most between two minors at
  1 MiB, 452,036 entries over the bootstrap, from 340,898 `:=` and
  469,232 `Array.update` that made an old object point at a young one.
  No `SETENV` ever did at a nursery of 512 KiB or more, on the
  bootstrap or any of MLton's programs (8 of 8,863 did at 256 KiB): a
  recursive closure is closed within a quarter megabyte of being made.
* **An old space marked in place** (sticky mark bits) would mark
  208 MB and sweep 372 MB in six collections where the copying one
  copies 172 MB in seven; its fragmentation is not modelled.
* **Large objects are a small part:** those of 2 KiB and more are 6.1%
  of the bytes the bootstrap's copier moves (2,095 objects, 3.3 MiB
  live at most), 3.3% at 32 KiB. A space of their own was designed in
  and not built (heap-layout D6).
* **A lazy program's updates are mostly young to young.** In six lazy
  programs (`examples/benchmarks`, a suspension as a ref) a nursery of
  1 MB would have to remember 0.06% to 6.7% of the updates, one of
  4 MB 0.02% to 1.9%, and never more than 4,146 entries at once
  (`heap-layout.md`, *M4, for a lazy front end so far*).

What the simulator does not model: locality, the barrier's cost in the
running code, fragmentation, and pauses.

## What is in place

Built and tested in heap-layout M6 and M7 (`make test-heap`;
`docs/runtime.md`, *What is in place for a collector to come*):

| Hook | Where | What it costs today |
|---|---|---|
| Four bits of the header: two of age or colour, remembered, pinned | `runtime/value.h` (`OBJ_GC_*`): named, asserted, zero; the copier carries them, an image leaves them out | nothing: every reader of a kind reads the byte whole (`obj_kind` in C, `kind_is` in compiled code) |
| Readers that take the kind's bits alone | the same two, under `RUNE_GC_BITS` (`bin/runevm-gcbits`, whose collector sets the bits on every object it copies) | in that build: 2.5% more instructions in the interpreter on the bootstrap, C's mask and the bits written at every copy; at the default tiering 4.4% more on the bootstrap and 9.8% on `tailmerge`, an upper bound for compiled code, which tests the kind bit by bit there where a collector would load, mask and compare |
| The barrier, one operation | `obj_set_field` and `BARRIER` in C; `ms_barrier` after the store in compiled code | nothing. As a card mark of four instructions at every store (`bin/runevm-cards`): 0.3% more instructions on the bootstrap, 4.7% on `imp-for` (a loop of `:=`), 3.6% on `array_sieve`; in cycles under the 3% to 4% that runs differed by that day |
| Young by address | `heap_is_young`, `runtime/vm.h` | nothing: no one asks yet |
| An object becomes an indirection in place | `obj_become_ind`; the collector follows its first field alone | nothing: no program does it |
| The allocation state as the thread's, the collector's as the VM's | `AllocState`, `GcState`, `runtime/vm.h`; no variable of the collector is the process's | nothing measurable (the collector's time on the bootstrap is the same) |
| Roots by what is live | `VM.frame_live`, `runtime/register/live.c` | saves: 12% of the bootstrap's copying |
| The roots listed once | `OTHER_ROOTS`, `runtime/heap.c` | |

What is not there, and is this roadmap's to take up:

* No reader masks the header's bits but in the VM built for it, and
  nothing through heap-layout's M8 sets one (the FFI's pinning is a
  copy in and out around the call until there is a space that does
  not move). A collector that sets them makes the mask the build (in
  compiled code a load, a mask and a compare where there is one
  compare, at every test of a kind that the representations do not
  vouch for) or puts its bits somewhere else (a side table by address,
  as the cards are): an age only matters if promotion waits for a
  second survival, a remembered bit only for a list of remembered
  objects, a pin only with a space that does not move.
* `runeopt`'s templates are made from the macro-assembler and take the
  barrier when it has a body (since garbage-collector-v2's M2: until then
  `:=` and `Array.update` stored through `storeField`, which has none, and
  now through `setField`, made from `ms_set_field`); nothing of them was
  measured with one.
* The frame that runs keeps every register as a root
  (`docs/runtime.md`); a collector with a nursery scans that frame at
  every minor.
* `Runtime.stats` is as it was. The fields a generational collector
  would report, to be added once with it: minor and major collections,
  bytes promoted, the remembered set at its largest, the longest
  pause (which `--stats` has).
* No large-object space, no pinning (heap-layout M8 plans the pin bit
  for the FFI's byte objects).

## Questions the roadmap has to answer

1. **Is it worth building for the programs Rune has?** The simulator's
   answer for the compiler is: not in bytes copied at the heap it runs
   in, yes in memory and in pauses. So the roadmap states first what it
   is for (memory and pauses, or throughput at tight heaps) and
   measures that, with a prototype on the bootstrap before anything is
   decided, as heap-layout's M4 did.
2. **The nursery's size**, against the cache (the reference machine's
   L2 is 256 KiB, its L3 20 MiB) and against survival, which falls
   slowly with size here.
3. **Promotion:** at the first survival or the second. The header has
   two bits of age for it; the simulator has both policies.
4. **The old space:** copied (what the copier is), marked in place
   with the sticky bits, or blocks in the manner of Immix. The numbers
   above are for the first two; fragmentation and locality need a
   prototype.
5. **The barrier's body:** a card mark (measured: under 5% of
   instructions on a loop that does nothing but store), a list of
   remembered objects with the header's bit, or none for immutable
   objects with the mutable ones in a space of their own that every
   minor scans (Poly/ML's way; refs and arrays are few in SML). And
   whether `SETENV` needs one at all above a nursery of 512 KiB.
6. **Growth and memory:** the old space sized by what is live with a
   fine step, the nursery fixed; what `--heap-size`, `--heap-fill` and
   `--heap-limit` mean then, and what an image carries.
7. **Pauses:** what is promised, and measured how. The copier's
   longest collection is in `--stats` now: 62 ms on the bootstrap.
8. **Determinism:** a program collects at the same allocations in
   every run today (`docs/runtime.md`, *The same run twice*), and
   `--count` is exact on every engine. Both hold for the next
   collector, or the roadmap says what replaces them.
9. **Threads:** a nursery for each thread is `AllocState` made many;
   whether old space is shared, and what the barrier becomes then, is
   the multithreading roadmap's to ask and this one's to leave open.
10. **A lazy front end:** the collector can short-circuit an
    indirection when it copies (`K_IND` is followed through its first
    field already), and an update is a store through the barrier.

## What holds whatever is decided

One collector for every engine, in C17, behind the interface of
`runtime/value.h`; the interpreter complete without the JIT; the
32-bit and big-endian VMs kept; images that cross machines;
`--gc-stress 1`, the sanitiser and `make test-heap` green; the budgets
of `tests/perf` exact; `make test-portability` before a change to the
heap is done.

## Where the numbers are

`heap-layout.md`: *The simulator* and *What the bootstrap says about
the collector to come* (survival, the remembered set, sticky bits,
large objects), *M4, for a lazy front end so far*, *M5, done*, *M6,
done*, *M7, done* (the growth steps, the barrier's and the mask's
cost). `tools/heapsim` and `scripts/census.sh` make the simulator's
tables again; the traces of the bootstrap and of six of MLton's
programs were archived to `/mnt/h/HEAPSIM/heap-layout/traces`, all of
the 16-byte layout; those of the word layout are
garbage-collector-v2.md's (docs/census.md, format 2).
