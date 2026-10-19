# GAMTEB reference and host diagnostics

Keep primary profile checks separate from broader arithmetic and raw-stream
observations. The portable kernel and numerical driver do not patch host
arithmetic or change canonical nursery settings.

Initial raw-stream checks at seven particle counts pass under both policies on
Rune, MLton, 32-bit legacy SML/NJ, development SML/NJ, Poly/ML and ML Kit.
The 64-bit legacy host fails both result/statistic checks at 5000 particles.
A separate replay changing only nursery size fails four of 28 assertions at
128 KiB and passes all 28 at 64 MiB. This is sensitivity evidence consistent
with the existing legacy GC report; it does not alone establish that cause.

The exact formatter roundtrip check detects a 32-bit legacy scanner difference:
Math.ln 0.001 formats as -6.907755278982137, but scanning that decimal gives the
neighboring value printed as -6.907755278982138. The other five native hosts
roundtrip this value. This is an operational roundtrip limitation of this
configuration; no broader language-conformance theorem is asserted.

A standalone tuple probe separates arithmetic from representation. Four real
values returned directly through a generic delay functor work on all hosts.
When the same tuple is returned inside a reference, external matching reads
garbage on all three SML/NJ hosts under the identity delay policy. Internal
access and the lazy policy work; Rune, MLton, Poly/ML and ML Kit pass.
This is related to the PIC type-constructor representation report and explains
why broader tests that expose memoized real tuples can fail independently of
the kernel's internal scalar accesses. The source checks retain these failures.

A plain scalar reduction also reproduces the Klein helper discrepancy at energy
2 and random input 0.999: all SML/NJ hosts produce approximately
0.4007461529340375, while GHC and the other hosts give 0.40074615290971516.
The printed logarithm and fit coefficients agree; the final exponential
approximation is implicated. This roughly 6e-11 relative difference exceeds
the auxiliary 1e-11 bound but is distinct from the primary 1e-10 weight bound.
The [MATH specification](https://smlfamily.github.io/Basis/math.html) does not
state a universal ulp bound. Record it as an arithmetic diagnostic discrepancy,
without inferring a compiler-conformance violation.

The first private driver eagerly formatted its global prefix during module
initialization. The final driver restores the original lazy cached prefix,
so unused or zero-repetition calls do not perform that work. Positive profiles
still enforce the same roundtrip check. Initial and final attempts remain
separate, with no failing result accepted as a timing sample.

The recorded full checker also finds a negative-zero formatter roundtrip
failure under native MLton defaults for both policies. Its primary smoke and
normal profiles pass; the additional signed-zero case is outside their observed
positive result weights. The raw initial and final transcripts distinguish the
different outcomes. No compiler-option or library-cause claim is made without
a reduced control experiment.
