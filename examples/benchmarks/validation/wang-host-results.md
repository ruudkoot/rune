# Wang numerical host checks

The two imported variants pass all 56 smoke/normal profile cases, including
Rune's four engines at O0/O2 and six native hosts supplied by make hosts.
The separate 37-check program includes varied numerical inputs that distinguish
the original source recurrences and block pairing. Its two invocations record
14 successful full runs, four runs with incorrect results, and two runtime
failures. Of 740 planned assertions, 714 pass, six fail, and 20 remain unfinished
because the two 32-bit host processes abort.

| Host | Default auxiliary result per invocation | Separate 64 MiB nursery replay |
|---|---|---|
| Rune (all four engines), MLton, Poly/ML, ML Kit | 37 pass | not needed |
| SML/NJ 110.99.9, 64-bit | 35 pass; strict nonuniform sizes 5 and 7 fail | 37 pass |
| SML/NJ 110.99.9, 32-bit | 27 completed passes, then runtime abort | 37 pass |
| SML/NJ 2026.2 | 36 pass; strict nonuniform size 7 fails | 37 pass |

Observed incorrect first values include a tiny subnormal and NaN where the
original GHC program and independent blocked model return one. The 32-bit
transcripts include a bogus fault or a bad object tag. The default diagnostic
replay reproduces failures; all three supplied SML/NJ hosts pass with
@SMLalloc=64m. The replay changes only that runtime argument. The archived
[diagnostic source identities](../../../../rune-benchmark-results/m3-wang/host-diagnostics/diagnostic-source-identities.tsv)
identify kernel/driver/checker bytes, also used by the imports.

These outcomes establish sensitivity to garbage collection. Their exact cause
is unreduced. The local [legacy root-saving report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md)
has a narrower documented platform scope. The [spilled-number report](../../../docs/bugreport/smlnj/GC/spilled-word64-argument/BUGREPORT.md)
and upstream [legacy issue 381](https://github.com/smlnj/legacy/issues/381)
are further references for investigation.

Upstream [issue 394](https://github.com/smlnj/smlnj/issues/394) is closed. Its
[resolution discussion](https://github.com/smlnj/smlnj/issues/394#issuecomment-5750145843)
describes changes to arity lowering and raw numeric records for 2026.3;
a [later comment](https://github.com/smlnj/smlnj/issues/394#issuecomment-5901993103)
records the new implementation. Public issue-state metadata was fetched on
2026-10-16 and retained. The suite's supplied host identifies as 2026.2. Those
reports do not establish Wang's cause or results on a newer upstream build.

The benchmark keeps its source representation, numerical bounds and default
host settings. The larger-nursery runs remain diagnostics. All raw outcomes are
retained; failed correctness cannot supply a timing sample. The profile ledger,
auxiliary semantic ledger and nursery replays have distinct scopes. Recheck the
same fixtures when refreshing the supported hosts.
