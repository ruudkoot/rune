# Wang blocked numerical workload

All 56 canonical smoke/normal cases pass: two variants, Rune's four engines at
O0/O2, and six native hosts at compiler defaults. Eight normal count samples
agree under the execution-model rules, including allocation across all Rune
engines. Existing budgets are unchanged; these new profiles remain unbudgeted.
Six serial single fresh-process native smoke samples validate the adapters.
They are diagnostics, separate from headline timing comparisons and counts.

The public 37-check program has 14 complete passing runs, four with incorrect
results and two runtime failures. It records 714 passing assertions, six failed
assertions and 20 unfinished assertions after 32-bit SML/NJ aborts. The semantic
summary records planned/completed counts and separate failure categories.
Default and larger-nursery replays are retained alongside the source identities.
The host note links existing SML/NJ reports and current issue-state metadata;
its exact application-level cause remains unreduced. Default host failures are
preserved independently of successful profile validation.

The unmodified Haskell program matches all three complete 500-line fixtures.
Full numerical observers and an independent mutable blocked model agree bit for
bit on 29780 uniform and 124 nonuniform values. SML checks use explicit bounds;
nonuniform fixtures distinguish source diagonal/residual division and f_dist
block pairing. Tests also cover original checksums, repeated output formatting,
unused fields, shared factors and deliberately perturbed/nonfinite results.

Both whole-program normal and large Rune O2 pilots pass with all 500 original
repetitions. Their resource guards and preserved sources/program hashes are
recorded separately from headline samples; compiled artifacts are not included.
Smoke reduces only repetitions to one at the original FAST block size 25.
Normal/large retain sizes 80/150 and all 500 repetitions. Every generated scalar
is consumed and checked; every original rendered character contributes to the
checksum. Exact sources, profile adaptations and upstream notices are retained.

The full repository acceptance check exits 0; its complete transcript is linked
in validation.md. M3 remains in progress.
