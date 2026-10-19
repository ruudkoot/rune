# hash provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/hash/hash.hs` and `HashTable.hs`.
The retained table source credits the University of Glasgow (2003), gives a
BSD-style notice and identifies the earlier Data.HashTable module. The base
BSD licence is retained. It cites Per-Ake Larson, Dynamic Hash Tables, CACM
31(4), April 1988, pages 446-457. The driver author is unspecified.

Preserve mutable bucket arrays, a reference to strict table state, association
lists, initial eight buckets/mask seven, load factor seven, hysteresis 64,
stable doubling partitions and maximum mask 33554431. The exact growth condition
is count-64 > 7*mask, not bucket-count times seven. Each insertion retains earlier
entries. The benchmark needs new/insert/lookup; unused library APIs and disabled
instrumentation are not added to the SML kernel, while the complete original
module is retained for provenance.

The hash multiplies by 1013904242 and extracts the high 32 bits before adding
the key. Selected nonnegative inputs/products fit the original signed ranges;
Word64 implements the wide product/shift and SML machine integers hold the final
hash and counters. SML31-bit hosts can represent every selected counter/hash;
no arbitrary-precision replacement is used in the kernel. The independent
checker uses IntInf to verify placement mathematically, so a host word bug cannot
validate itself merely by repeating its faulty hash function.

Original GHC lookup returns Just 100 at all selected sizes. The port additionally
consumes every stored key/value, detects missing/duplicate/out-of-range entries,
validates placement against the exact formula and checks n(n+1)/2. The checker
and its temporary seen array add work/allocations and are included. Selected
sizes are 128/10000/1000000; large preserves original FAST. Original NORM5000000,
SLOW100000000 and heap settings remain recorded, not universally executed.

Growth, bucket chains, stable redistribution, integer representation and retained
entries are source hypotheses until measured. Reference: retained HashTable
module and its Larson citation, plus the nofib survey. No compiler/runtime
features or alternative hash-table algorithm are introduced.
