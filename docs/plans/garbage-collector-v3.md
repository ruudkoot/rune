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
