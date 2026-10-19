# sat provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/sat/main.sml.
Copyright 2025 Fellowship of SML/NJ; notice and original retained.

Preserves the nine-clause formula, ten nested higher-order Boolean choices,
true-before-false search order and first-satisfying-assignment stopping.
Removes candidate logging and consumes every returned Boolean. An independent
1024-assignment truth table finds 80 satisfying assignments,
including the three unused variables. Normal repeats 10000 solves; large
retains the original million. Allocation, closures and short-circuiting are
diagnostic hypotheses, not measured findings.

The upstream copy writes its one non-ASCII literal, `"φ("`, as the escapes
of its UTF-8, `"\207\134("`, which Rune's default needs (docs/plans/utf8.md,
D6); it means the same bytes.
