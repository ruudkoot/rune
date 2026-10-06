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

## Interesting references
- https://go.dev/blog/greenteagc
