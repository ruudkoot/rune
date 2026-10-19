# Sequential Graph500 host findings

The canonical primary matrix records 70 passes and fourteen failures.
All Rune, MLton and ML Kit cases pass. The three families retain different
source algorithms and result consumers, so separate their failures.

SML/NJ computes Math.pow (2.0, 3.0) as approximately 7.999999999999998; the
prototype's source truncation chooses seven rather than eight vertices.
The normal scale also changes its dimension. Preserve the source operation;
this is a source rounding sensitivity, not a claim that all power functions
must be correctly rounded. These inputs cannot provide comparable timings.

Poly/ML converts the already integral real 9007199254740991.0 to
9007199254740992 using Real.toLargeInt TO_NEAREST, while TO_ZERO retains the
original integer. A second integral control at 4503599627370497 also differs.
The portable codec's valid nearest conversion remains; it changes low encoded
weight bits on that host. [The Basis REAL conversion contract](https://smlfamily.github.io/Basis/real.html#SIG:REAL.toLargeInt:VAL)
and standalone original inputs/results are recorded.

Legacy 32-bit SML/NJ gives a different unsigned header word for the typed
literal and constant shift/or construction than for runtime parsing/conversion.
The expected word is 8495A6BE; the observed literal form is 0495A6BE.
Its encoded file begins with 04 rather than 84, and decoding rejects the
original input before edge assertions run. The compiler mechanism is unresolved;
the benchmark retains the valid literal and ordinary operations.

The corrected final word probe uses decimal 2224400062 and checks complete
word equality as well as its top byte. An earlier development probe used a
different decimal value and checked only the top byte; do not treat that
difference as a compiler failure.

Legacy 64-bit SML/NJ also produces different normal generation/adjacency hashes.
One semantic compilation context fails edge 28 and adjacency validation in
addition to the prototype; another fails only the prototype. Small isolated
arithmetic controls do not establish the mechanism of these additional failures.

Optional packing structure names differ between Poly/ML and SML/NJ. The final
codec uses common SML97 decomposition/scaling and integer/word operations on every
host. Earlier optional-API source snapshots and transcripts remain development
evidence, separately from canonical results.

The native measurement precheck's quoted Poly/ML Fail output exposes a status
classifier gap. Raw sample statuses remain as recorded; reviewed dispositions
identify the explicit incorrect result. No failed precheck supplies a timing.
