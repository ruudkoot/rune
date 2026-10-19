# paraffins-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/paraffins/Main.hs`.
Steve Heller's Id example, forwarded from MIT by RPaul and acquired by SLPJ
in August 1993 according to the retained source. No individual licence notice is
supplied; record the gap. Retain the source, optional C implementation, build
manifest and upstream fixtures with SHA256 identities.

Preserve three/four-part partitions, suffix-based selection of repeated-size
radicals, immutable shared subtrees, the lazy array of radical rows, and bridge/
vertex-centred paraffin generation. Each invocation produces all four original
count vectors: radical rows, bridge centres, vertex centres and their combined
counts. Separate generators for those observations remain separate, while the
combined function shares one generator for both centre forms.

The lazy port has memoized row/spine/head cells and delayed constructor fields.
Its length observer forces list spines but leaves radical/paraffin values
unforced, as the original count-only workload does. The strict variant builds
ordinary lists and constructor objects eagerly. Representation, demand, retained
subtrees and possible constructor elimination differ materially. The shared
partition arithmetic retains the original ceiling operation on small, exact
half-integer arguments. No closed-form counting algorithm replaces the kernel.

Independent combinatorial fixtures count combinations with replacement for
equal-sized branches and independently enumerate centre partitions. They agree
with the original Haskell observer and all four selected count vectors; the
combined counts include 159 at 11 carbons and 1858 at 14. Every vector is rendered
and compared in full, then the actual count sum is consumed. Profiles are
(4,1), (11,1), (14,1000); normal/large preserve original FAST/NORM sizes, and
large retains 1000 source repetitions. SLOW size 15 remains recorded.

References: the original Id/source provenance, the nofib survey, and the
[alkyl-radical](https://oeis.org/A000598) and [alkane](https://oeis.org/A000602)
count sequences for additional mathematical context. Performance effects of
sharing, demand, object lifetimes and compiler elimination are hypotheses until
measured on these ports. Large execution is not universally claimed.
