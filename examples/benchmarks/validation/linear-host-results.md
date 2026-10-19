# Linear solver host findings

All 64 primary Rune smoke/normal cases pass across four source/evaluation
variants at O0/O2. MLton, 32-bit legacy SML/NJ, development SML/NJ, Poly/ML and
ML Kit pass their 40 native primary cases. Legacy 64-bit SML/NJ 110.99.9 fails
all eight primary cases, for 104 passes in 112 attempts.

The canonical semantic target records 1341 passes and 39 failed assertions
across twenty 69-check invocations, with no unreached checks. Legacy 64-bit
SML/NJ records 58 passes/eleven failures in one context and 41/28 in the other.
All eighteen remaining invocations pass all checks. An earlier private context
records 45/24. Report these actual contexts rather than one assumed fixed host
failure count.

Failures include original dense inversion/scaling/preconditioning values and
displayed iteration metrics. The small binary32 edge-case controls and original
higher-order demand checks remain separately visible. The mechanism of the
additional legacy differences is unresolved; no compiler, nursery, arithmetic
or tolerance workaround is introduced.

Initial private native builds needed an explicit scale/preconditioner signature
so both projections of the returned matrix/vector tuple have a closed SML
record type. This portable annotation fixes a translation typing issue;
those earlier build failures are distinct from the later numeric findings.

Original Haskell fixtures and exact binary32 metric observers supply reviewed
expected values independently of SML/NJ. The fifty-state GC normal result reaches
its source iteration cap with nonzero residual. Matching that source result is
not a general accuracy/convergence claim.

Every successful final normal Rune case and count sample refers to the generic
higher-order callback implementation. Earlier private calibration drafts are
retained as development evidence, separately from canonical source identities.
Incorrect results cannot supply accepted timing samples.
