# Reference-host failures

Checked 2026-10-02 after rebasing benchmarks onto master `3d48b00`.
Incorrect host output remains a failed check. It is not accepted as an
alternative expected result, and it cannot contribute a timing sample.

## SML/NJ legacy

The managed `make hosts` installation is the 110.99.9 release. The existing
[GC-root reproducer](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/bug.sml),
run with its own Basis and `@SMLalloc=128k`, reports **591 of 300000 wrong**.
The observed failures include a real's bits becoming zero or a heap address.
The transcript is retained as [smlnj-legacy-gc-roots.log](smlnj-legacy-gc-roots.log).
This directly establishes that this installation has the reported GC defect;
it does not establish which benchmark differences the defect causes.

The [local report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md)
explains the mismatched root lists. Upstream [issue 299](https://github.com/smlnj/legacy/issues/299)
is now closed, and [commit 6d34c629](https://github.com/smlnj/legacy/commit/6d34c629458fb8392e51a2a0231e4cca25d4b8d8)
changes those list comparisons to require equal lengths. The fix has not
been installed into our managed release host.

A fresh normal Barnes-Hut comparison still fails on legacy 110.99.9 with
`body state differs`, and passes on managed SML/NJ 2026.2 with the unchanged
fixture (`256 81`). MLton, Poly/ML and the four Rune engines also passed
that fixture in the recorded import checks. GC corruption is a candidate
explanation for the legacy result, not an isolated cause. A patched-host
rerun or a reduced reproducer is required before attributing it to issue 299.

Other relevant reports include [issue 381](https://github.com/smlnj/legacy/issues/381)
for spilled 64-bit arguments and [issue 390](https://github.com/smlnj/legacy/issues/390)
for real-to-integer conversions. The local
[report index](../../../docs/bugreport/smlnj/README.md) records their triggers
and fixes. Avoid interpreting a host disagreement as a Rune regression
without checking those triggers and an independent reference.

## SML/NJ 32 bits and other hosts

The [Word64 diagnostic](word64-host.md) records release-literal and arithmetic
failures affecting seeded TSP, AOBench and Monte Carlo ray inputs. The
relevant upstream discussions include [issue 260](https://github.com/smlnj/legacy/issues/260),
[issue 373](https://github.com/smlnj/legacy/issues/373) and
[issue 388](https://github.com/smlnj/legacy/issues/388).
Id-ray's normal difference remains unisolated. Sandbox SIGSYS attempts and
actual unsandboxed result failures are recorded separately.

Poly/ML lacks the required Int64 facilities for the vector64 programs. ML Kit
has recorded compiler and numerical failures on some larger classic programs.
[The attempt ledger](m2-attempts.tsv) retains these failures. A green Rune
validation target does not imply that every reference host passes every
program. The suite keeps the same sources and checkers across hosts.
