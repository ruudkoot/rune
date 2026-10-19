# mutstore1 provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `gc/mutstore1/Main.hs` and Store1.hs.
No individual author or licence notice is supplied; keep that gap explicit.
Original source/build manifests and their SHA256 identities are retained.

Preserve ten buckets per store, bucket index 3, inserted value 17, five insertions
per testSequence and five full passes over the retained store list. Variant 1
uses an immutable vector of references to lists; variant 2 a mutable array of
lists. These are distinct layout/update workloads, not duplicate implementations.
IORef/IOArray operations become ordinary SML refs/arrays with the same state and
traversal order. All stores remain live through all passes and the final checker.
SML integer widths differ from GHC's 64-bit Int, but every selected value/count
fits supported widths; no wrapping arithmetic is required.

The originally discarded state is now observed: every bucket has its expected
length and all values are 17, then actual store/entry/value totals are consumed.
Original GHC observers agree with the independent 25*n and 425*n arithmetic
checks. This added scan is included in the port's work and extends retention
through validation. Selected store counts are 4/1000/100000; large preserves
original FAST. Original NORMAL/SLOW and heap settings remain in the Makefiles.
Large SML execution is not universally claimed. Allocation, write costs and
retained lists are source-derived hypotheses until separately measured.
References: pinned nofib source and suite survey; compare the two source layouts.
