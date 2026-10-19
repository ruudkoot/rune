# tyan-smlnj provenance

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/tyan`.
All source modules/notices and adaptation patch are retained.

Thomas Yan's F17 Geobucket polynomial calculation, modern SML/NJ
modular version. Preserve field arithmetic, monomial/trie representations,
heap-polynomial operations, auto-reduction and cyclic-u6 input. Source
headers credit the modern Fellowship version; historical authorship is
shared with the classic TIL-derived variants. Keep maxDeg=1000000 and
192 calls in large. Suppress progress; consume every computed leading
monomial and term count. Do not replace F17 by rational arithmetic.

Complete computed traces influence a Word32 checksum; empty output fails.
No measured causal attribution is claimed. See the rewriting/Geobucket
references in [the literature](../literature.md).
