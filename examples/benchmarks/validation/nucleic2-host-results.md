# Nucleic2 host observations, 2026-10-18

The initial serial smoke adapter pilots pass for all four variants on
MLton 20241230 and Poly/ML 5.9.2: eight fresh samples and preflights.
All four legacy SML/NJ 110.99.9 preflights fail with a domain exception.
These failures contribute no timing samples.

An isolated diagnostic kernel records a value near 7.115e-307 at a square
root call, whose result leaves the selected finite-normal binary32 domain.
The public kernel and error bounds are unchanged.
Rerunning the same compiled default-lazy image with @SMLalloc=128k or 1m
retains the domain error; @SMLalloc=128m instead produces an incorrect
maximum. This is observed sensitivity to collection settings, not a proof
of a particular compiler/runtime cause.

The repository's [real-value GC report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md)
describes related legacy corruption. The separate
[abstract-type constructor report](../../../docs/bugreport/smlnj/Datatype/real-pair-through-type-constructor/BUGREPORT.md)
also matters when auxiliary tests unpack real fields outside a functor.
Neither report is asserted to prove the cause of this benchmark failure.
Valid kernel computations and external-pattern tests remain unchanged.

The completed semantic matrix has fourteen configuration groups. All 5081
assertions pass in each of twelve complete groups: all four Rune engines
at O0 and O2, MLton, Poly/ML, 32-bit SML/NJ and development SML/NJ.
Legacy 64-bit SML/NJ records 89 passing and 65 failing assertions before
a fatal exception; its remaining checks did not execute. ML Kit produces
an empty compilation log and no assertions, with the cause unclassified.
The total recorded outcome is 61061 passing and 65 failing assertions;
incomplete groups are retained as incomplete.

Development SML/NJ passes the complete semantic test and all four normal
profiles. Its smoke attempts have three 30-second timeouts while loading the
kernel and one explicit allocation failure under the 1-GiB process limit.
The latter prints unable-to-map and unable-to-allocate diagnostics; compilation
and eager initialization share this interactive process, so its phase remains
unclassified. These development-host failures are distinct from the legacy
runtime's domain errors. ML Kit passes all four normal profiles; its lazy
and shared-lazy smoke compiles have empty logs and unclassified causes.

The final profile matrix has 98 passing combinations out of 112. All 64 Rune
combinations pass across four variants, smoke/normal inputs, four engines and
O0/O2, after the recorded shared-strict smoke override. Keep all 116 attempts,
including the four earlier 30-second Rune smoke timeouts. Legacy 64-bit SML/NJ
fails all eight smoke/normal combinations with domain errors. The remaining
six nonpassing combinations are the development-host and ML Kit smoke
outcomes described above.

All sixteen normal allocation-count samples agree across the four applicable
Rune engines. The memory guards complete without intervention. The final
serial native adapter diagnostic retains eight passing fresh-process
samples from MLton and Poly/ML and all four rejected legacy SML/NJ
preflights. These single samples are adapter checks, not performance claims.

The repository acceptance run passes, including all 498 compiler comparisons
and seven-host runedoc and runeopt agreement. Private GHC and independent
oracles, incomplete host groups and final profile outcomes are retained
in the [complete evidence archive](../../../../rune-benchmark-results/m3-nucleic2/README.md). No numerical bound or valid kernel computation has been weakened
to accommodate a host failure.
