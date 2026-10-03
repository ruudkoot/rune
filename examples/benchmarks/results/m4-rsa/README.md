# nofib RSA application

Recorded 2026-10-03. Memoized and strict RSA ports share the exact source
modular-power recurrence, large keys, base-128 coding and block-size rule.
M4 remains in progress for other applications.

[The attempt ledger](correctness-attempts.tsv) retains the original six-block
smoke timeout and all 48 final primary smoke/normal cases. Final cases pass
on four Rune engines at -O0/-O2 and four primary managed native hosts.
The selected smoke input is a 64-byte prefix: one full exponentiation with
the original key widths. Original GHC and independent Python modular pow
agree on every selected ciphertext block and hash sum. No universal large
SML execution is claimed.

Eight semantic checks pass nine configurations at both levels, including
zero-exponent demand, exact block coding, exponent parity and empty input.
ML Kit crashes compiling the paired-functor semantic test; its error and
[reproduction](../../validation/mlkit-compress.md) remain separate from
benchmark correctness results. No compiler workaround is introduced.

Repeated binary input reads replace nofib's NOINLINE IO salt, adding an
explicit input/copying cost. Output materialization and full ciphertext
validation are recorded adaptations. Count archives retain complete samples,
source/input/tool snapshots and configuration metadata. All four engines'
allocation counts and applicable instruction comparisons agree. Instrumented
times are not headline performance comparisons.
