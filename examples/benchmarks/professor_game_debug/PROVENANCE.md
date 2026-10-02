# professor_game_debug provenance

ML Kit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test_dev/professor_game_debug.sml`.
Niels Hallenberg, 27 December 1995. Original source/header, aggregate notice
and adaptation patch are retained.

Keep the original sixteen fixed jacket/trouser cards, order, list copying,
row-major placement and matching search. Replace primitive mini-Basis
operations by SML97 where present, and suppress console/debug logging.
Retain first-success exception DONE, observing that exact first board.
Validate each board's tile multiset and every horizontal/vertical pair using
an independent colour/parity coding, then consume an order-independent
Word32 checksum of every complete board. This is additional checking work.
Normal preserves one complete search; large repeats four for scaling.
Source variants retain their custom list/helper organization rather than
assuming equivalence from names. Legacy optional profiling primitive names
are adapters, not added runtime facilities. The debug source's stray final
comment closer is outside the retained kernel. Search, copying and lifetime
are hypotheses; see [the ML Kit literature](../literature.md).
