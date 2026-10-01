# boyer-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/boyer.
Ordered original sources, notice and adaptation patch retained.

Modern modular SML/NJ tautology checker. Keeps the four-module property
list, rewrite rules, substitution and original theorem. Every actual result
must be true, as upstream testit requires. Large preserves 1300 repetitions.
Only the String.concatWithMap presentation extension is replaced by the
SML97 map/concatWith composition. This source organization and newer rules
remain distinct from the old MLton monolith until a full equivalence audit.
