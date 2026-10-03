# Exact series and sequential shootout workloads

Recorded 2026-10-03. Five ports cover GC/spectral power series and the three
remaining suitable sequential shootout programs: n-body, FASTA, and reverse
complement. Together with pidigits, all four eligible shootout workloads now
have validated ports. M3 remains in progress for other GC and spectral entries.
The catalogue contains 182 programs and 540 profiles.

[The ledger](correctness-attempts.tsv) retains 244 attempts, including rejected
initial ports. Final selected smoke/normal profiles pass on all four Rune
engines at both -O0 and -O2, and on the four primary managed native hosts.
Raw final stdout, compilation logs, and available compilation identities are
retained under correctness-raw; no universal large SML execution is claimed.

Power coefficients agree with original GHC observers, analytic identities,
and independent binomial Catalan counts. The GC version retains integer
generating functions, while spectral power uses rational coefficients for all
four expressions and 200 repetitions. Thirteen semantic checks cover exact
coefficients, finite polynomial boundaries, memoization, integration demand,
and division's numerator-before-denominator pattern demand. All ten managed
configurations pass at both optimization levels.

FASTA outputs agree byte for byte with unchanged Haskell and independent C.
The original binary32 lookup-table arithmetic remains explicit in SML97.
Reverse-complement fixtures agree with original Haskell, C, and independent
record/sequence reversal. Its rejected n=13 candidate exposed the original
reader's assumption of at most one new header per 82-byte chunk; smoke uses
n=100. The source algorithm and this limitation are preserved.

N-body checks both energies and all 35 state values. The independent force
integrator differs from GHC by at most 3.26e-12 for normal and 1.86e-9 for large.
The profile arguments record absolute/relative bounds of 2e-10/2e-10 for
smoke/normal and 2e-8/2e-10 for large. Seventeen shootout semantic checks
exercise float rounding/cutoffs, buffer growth/boundaries, and rejection of
perturbed, incomplete, or nonfinite states. All ten configurations pass at
both optimization levels. The initial wrong cutoff expectations were corrected
against independently reviewed binary32 arithmetic; the generator itself
already agreed with both originals.

Separate count archives preserve all instrumented samples and source/input/tool
snapshots. Applicable instruction comparisons and all four engines' allocation
counts agree. Instrumented times are not headline timing comparisons. Compiled
payloads and disposable work directories are excluded.
