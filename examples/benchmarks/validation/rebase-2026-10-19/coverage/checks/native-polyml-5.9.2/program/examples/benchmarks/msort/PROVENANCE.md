# msort provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/msort.mlb`. Original, adaptation patch and notices retained.

Alternating split mergesort (individual author not stated) with explicit copying of the
remaining merge argument. Ordered project members msort.sml, upto.sml and
msortrun.sml are preserved in upstream/. Normal keeps the original sorted
1..50000 input, not the pseudo-random input of kittmergesort. The driver
validates every element against its expected ordinal and returns length,
IntInf sum and Word32 hash. These fixtures are calculated independently.
The standalone library and invocation entries retain provenance in the
inventory without creating duplicate benchmark implementations.
