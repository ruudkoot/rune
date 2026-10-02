# FuhMishra provenance

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/FuhMishra.mlb`.
Pristine sources, observed source notices and adaptation patch are retained.

Mads's 1997 ML Kit port of the MATCH/TYPE subtyping checker from Fuh and
Mishra. Retain list-based sets, constraint generation/matching, type-variable
counter reset and all six original expressions/environment. Load lib.sml
before the application as the original project does. Move top-level six
invocations to a repeated portable driver and suppress progress printing.
Every byte of each generated TYPE/MATCH report is checked against the
unmodified upstream program's reviewed native output. File generation and
validation are measured work. No new type-inference/runtime feature is
introduced to Rune by this benchmark.

Diagnostic questions are hypotheses until measured. See the
[classic SML literature](../literature.md).
