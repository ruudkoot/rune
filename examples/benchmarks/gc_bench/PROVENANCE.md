# gc_bench provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/gc_bench/Main.hs`.
The retained source includes the Ellis-Kovac/Boehm benchmark's history and
limitations. John Ellis and Pete Kovac designed the original; Hans Boehm
modified it. The individual Haskell translator/licence is unspecified, recorded
as a gap. Retain the complete source notice, including its historical Java
listing, plus build manifests and source identities.

Port the Haskell variant: deeply forced immutable trees, top-down mutable trees
with two child references, two retained trees and a half-filled real array.
There is no extra stretch-tree phase in this Haskell main, despite the historical
Java example. Tree-size, integer iteration counts, depth stepping/parity and
mutable node labels are unchanged. Retain the original left-depth walk's zero
return value rather than silently fixing it. SML's strict immutable construction
replaces Haskell deepSeq; refs replace IORefs, and arrays replace IOArray Double.

Driver CPU-time reads and the unused old-time import are removed from the SML
program; external tools measure execution. A GHC read-only observer removes only
the unused System.Time import to build on the reference host. It agrees on both
retained tree sizes/labels and array fill counts. Full temporary/retained tree
observers count actual nodes, validate immutable zero labels and mutable label
sum 2^(depth+2)-depth-4, and scan every array value with a documented reciprocal
relative bound 2^-51. These observers consume results and add traversal work,
including on mutable temporary trees; this is explicitly part of the port.
Independent tree-size/iteration formulas validate the consumed temporary total.

Profiles (retained-depth,array-size,min-depth,max-depth) are (4,32,2,6),
(12,16000,4,12), (17,400000,4,17); large preserves original FAST. The original
normal/slow dimensions and Haskell heap settings remain recorded. Profile limits
are operating-system quotas, not a claim of equal GC heap sizes or the original
32 MiB recommendation. The literature supports allocation/lifetime diagnostics
and explains limitations; this artificial workload is not a prediction of
application performance. Potential hoisting/sharing/elimination of pure immutable
construction is a compiler hypothesis until measured.
Reference: [Boehm's GCBench overview](https://www.hboehm.info/gc/gc_bench.html),
original source comments and the nofib survey. Large execution is not universally
claimed; no pause-time claim is made.
