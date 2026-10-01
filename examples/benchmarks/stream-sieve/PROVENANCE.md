# stream-sieve provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/stream-sieve`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ infinite stream sieve. The stream constructor
holds a strict head and a nonmemoized tail function. This differs from
the memoized nofib finite sieve and is intentionally retained. get uses
a zero-based index; large preserves 20000. Every requested prime is
consumed and checked against an independent finite Eratosthenes sieve.
The Streams and Sieve sources are compiled in dependency order, rather
than the textual order of the CM project.
