# fxp provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/fxp.sml`. Original, adaptation patch and notices retained.

Andreas Neumann fxp 1.4.4, in MLton's generated 2001 monolith. The source
version constant is retained; the source identity is the pinned MLton file.
[The archived project documentation](https://www.informatik.uni-bremen.de/cofi/CASL-CD/Tools/Cats/src/fxp/doc/)
identifies authorship. Its separate copyright/download links return 404;
the monolith carries no individual notice. The MLton project notice is
retained; recovering the original individual notice remains a provenance
check, not a claim that the aggregate notice describes every component.

Retains the null XML parser, symbol tables, Unicode handling and resolver.
Legacy Timer, vector/array iteration and Substring.all are adapted to the
current SML97 Basis. Iterators preserve absolute indices. No remote URI or
DTD retrieval is used. Explicitly disable validation for the generated
DTD-free document, fail on parser errors and consume start/end/attribute
event counts. Input generation and these additional hooks are part of the
measured workload.

A new portable SML recipe uses the old external helper's word/tag vocabulary
and depth/length distributions, with seed 12345 and exact Word32 ANSI-LCG
arithmetic modulo 2^31. It ensures unique attributes and correctly nested
children. The old awk helper used rounded floating arithmetic, could emit
duplicate attributes, and printed nested calls separately; these bytes and
old count baselines are not reused. Profiles select target payload byte
limits 8192, 1200000 and 4800000, permitting a final-element overshoot.

The URI retrieval helper checks OS.Process.isSuccess instead of comparing
opaque status values for equality, matching the current Basis contract.

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/fxp.sml`,
is an additional source for this implementation. The complete source agrees
with the MLton source after whitespace normalization, including its driver.
