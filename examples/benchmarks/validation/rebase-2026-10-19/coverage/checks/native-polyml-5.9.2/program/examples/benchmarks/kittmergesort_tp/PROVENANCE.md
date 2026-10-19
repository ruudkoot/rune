# kittmergesort_tp provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/kittmergesort_tp.sml`. Original, adaptation patch and notices retained.

Same sorting kernel and input generator as kittmergesort, with a materially
different ten-repetition in-process driver. The implementation is shared,
while this workload remains separately named and measured. Each invocation
regenerates its list from seed 1 and validates its entire sorted result.
Normal preserves the ten 100000-element calls; large scales the list length.
Every invocation summary is retained in the expected result, rather than
observing only the last call.

The copying kernel and validation live in shared/kittmergesort.sml, with
separate thin named drivers. Each compilation contains one Benchmark
structure; there is no alias/rebinding of another benchmark driver.
