# tyan provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/tyan.sml`. Original, adaptation patch and notices retained.

Thomas Yan multivariate polynomial/Groebner-basis workload. Preserves
the six cyclic equations, monomial trie, F17 modular/polynomial representations
and algorithm. Progress printing stays suppressed; consume only leading monomials and
term counts from the actual basis; complete reviewed upstream output accompanies the digest fixtures.
The additional textual observation and its allocation are recorded workload
changes. No claims about arbitrary polynomial correctness follow from this
fixed system.

Allyn Dimock adapted the TIL version to SML97; Stephen Weeks fixed the u6
input in 2001. The source explicitly records Thomas Yan's benchmark-use
permission and cites his 1998 Journal of Symbolic Computation article,
[The Geobucket Data Structure for Polynomials](https://doi.org/10.1006/jsco.1997.0176),
volume 25(3), pages 285-293. The source header misspells the title and gives
volume 23; bibliographic metadata is corrected here, with the original
header retained unchanged.
