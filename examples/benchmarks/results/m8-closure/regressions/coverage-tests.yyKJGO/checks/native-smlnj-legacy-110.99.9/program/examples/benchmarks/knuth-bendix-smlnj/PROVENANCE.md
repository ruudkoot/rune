# knuth-bendix-smlnj provenance

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/knuth-bendix`.
All source modules/notices and adaptation patch are retained.

Modern SML/NJ direct Knuth-Bendix completion. Preserve the geometric
equations, recursive path ordering, term structures, rule queues and
exception-driven rewrites. Retain 300 completions in large; normal selects
three. Capture actual computed rule/diagnostic output instead of console
logging. Unlike the ML Kit copying variants, this retains the direct
completion argument/exception organization.

Complete computed traces influence a Word32 checksum; empty output fails.
No measured causal attribution is claimed. See the rewriting/Geobucket
references in [the literature](../literature.md).
