- generational
  - nursery
  - large object space
- bibop
- concurrent
- cpu and numa topology aware
- reserved header bits 
  - ocaml5: 2 colour bits, per-domain minor heaps, a deletion barrier

## What the second generation leaves for this one

From `garbage-collector-v2.md` (its D16 and M8), what the third generation
starts from rather than undoes:

* **Allocation per thread.** A thread's room is `AllocState` (a nursery
  per thread is that struct made many); nothing of the collector is a
  variable of the process -- `GcState` is the VM's.
* **Side tables, not header bits.** The marks, the cards, the dirty bytes,
  a cycle's marks and the large objects' marks are bytes and bits in the
  tables of each 2 MiB chunk, which threads can set with atomic operations
  on bytes and words; a card mark is a plain store that does no harm twice.
* **One barrier that sees everything.** In every engine -- both
  interpreters, the JIT, `runeopt`'s code -- a store into an object that
  exists goes through one operation that sees the object, the field, the
  value stored and, before the store, the value overwritten: the card for
  the nursery and, while the low-pause collector marks, the snapshot's
  mark of the value overwritten, which a concurrent marker uses unchanged.
* **Work paced by allocation.** Minor collections, a cycle's slices and
  its end all fall where the bytes allocated put them, never at a timer,
  so the same run collects at the same points.
* **Two collectors.** `--gc throughput` (mark-region, the default: the
  least memory and time, its full collections stopping the program) and
  `--gc low-pause` (segregated fits whose objects never move once old,
  marked incrementally from a snapshot). The low-pause collector is the one
  to carry on: its marking is already a snapshot's, it never moves an old
  object, and its marking and sweeping touch the side tables alone -- what
  a marker on another thread needs.

What it leaves: promotion by many threads into a shared old space;
marking and sweeping in parallel; a safepoint protocol for many mutators;
NUMA placement; and whether the old space stays one or becomes one per
thread.

## To consider
- Rune compiling MLton 1.10 against 0.8. The cause is programs that promote data which then dies soon after; a survivor space, which was never measured, would be the next lever.
- Measured and dropped: prefetched marking, huge pages, smaller nursery maximums, and keeping the nursery outside the heap's size.
- Not built: pretenuring by site, worth about 1%.
- Low-pause, longest pause at large heaps: 37.6 ms on the 0.9 GB map, from first-touch page faults while the heap grows under WSL2, and 22.7 ms with 2.7 GB live, against 20 ms at a gigabyte. Low-pause pauses: longest 3 ms on the bootstrap and 1.5 ms at 100 MB live (target 10 ms); p99 under 2 ms everywhere.

## Left by the performance plan

[performance.md](performance.md), retired on 2026-10-20, made the code
faster and left the collector a larger share of what remains. Measured
on its last tip (*Where we ended* there):

* **The bootstrap's collector.** The compiler compiling itself spends
  34% of its cycles in the collector (minor collections 20%, the old
  generation 14%), where it spent 23% at master `921af2cc`: the code got
  faster and the collector did not. Its cycles, some 2.9G of 8.5G, are
  more than the whole gap to MLton's build of the compiler (8.5G against
  6.1G); the
  bootstrap allocates 1.55 GB in 57.9M objects (`runevm --count`). Native
  frames M9 measured 38% on a workload held fixed.
* **Deep stacks.** A minor collection walks every frame above the stack's
  watermark, and a recursion that goes deep and comes back, as a merge
  sort does, leaves most of its stack above it at each collection. On
  MLton's `merge` (`n` = 25) the tip of the performance plan
  (`a6a024ab1`) takes 13.7% more cycles than performance M1's runtime
  (`db0fba57a`), `wc-input1` 16.3% and `wc-scanStream` 15.2% (the least of
  seven runs each), for 4.6% more instructions on `merge` and fewer on the
  other two. The frames' walk is where they went (performance.md, *M10*):
  * by `--gc-log`, the collections of `merge` look at the same 2.83M
    frames on both, but at 12 slots a frame where 9 (25.2M against 18.9M
    in the minor collections) and 4 of them roots where 1 -- the header of
    three words that native frames M4 put below each frame;
  * by `perf record`, the frames' walks, liveness and return barrier
    (`scripts/perf-groups.awk`) take 37% of `merge`'s cycles where they
    took 11%, `vm_frames_from` alone 17%: about 170 cycles a frame walked
    where they were 40 (`wc-input1` 110 where 35). M1 indexed
    `vm->frames`; the walk steps through each frame's header to find the
    one below, and builds the array the collector reads.
  What is left to try: a walk the collector does in place, frame by frame,
  rather than an array of every frame; and a header the walk does not have
  to step through to find a frame's size and liveness.

## Interesting references
- https://go.dev/blog/greenteagc
