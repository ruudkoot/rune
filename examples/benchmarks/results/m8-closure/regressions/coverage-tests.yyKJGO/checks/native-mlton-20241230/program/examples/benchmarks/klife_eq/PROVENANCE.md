# klife_eq provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/klife_eq.sml`.
Individual author/notice is not identified in this file; the three aggregate
ML Kit/GPL/SML-NJ notices and pristine source are retained without claiming
that every aggregate notice applies to this individual program.

Retain double copying of generation arguments, survivor lists, dead-neighbor
lists, newborn lists and explicit boolean copying. The neighbor function is
passed explicitly and equality uses ordinary polymorphic equality. Normal
preserves the original three 50-generation calls; large selects 250.

Wrap the original outer let/local declarations in LifeKernel to expose iter
and alive. Suppress per-generation progress and ASCII rendering; consume
every final sorted coordinate in the same fixed Word32 summary used by the
other Life variants. Retain algorithms, custom list functions, generator,
copying and ordinary integer arithmetic. Selected coordinates fit 31 bits;
the checksum is explicitly modulo 2^32. Smoke selects ten generations once.

Fixtures come from an independent set-based eight-neighbor simulation of
the exact 44-cell glider-gun seed, with sorted-coordinate checksum review.
They agree mathematically with life-smlnj; these implementations differ in
copying, equality specialization and argument shape and remain separately
named. Those differences are source-based diagnostic hypotheses, not
measured causal findings. See [the ML Kit region/lifetime literature](../literature.md).
