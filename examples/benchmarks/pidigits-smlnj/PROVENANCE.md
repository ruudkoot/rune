# pidigits-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/pidigits`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

Copyright 2026 Fellowship of SML/NJ. Preserve the linear-fractional
IntInf spigot and original nonmemoized Stream.unfold/map combinators. The
consumer forces exactly the requested digits; no sharing/memoization is
introduced. Unlike old MLton pidigits, stopping counts digits rather than
zero occurrences. Normal 100 digits fits Rune; large retains original 2000.
Capture all digits and omit human column formatting. Independent Chudnovsky
fixtures are shared with the separately named iterative version.

All selected profiles retain meaningful source parameters; diagnostics intinf,streams,arithmetic
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).
