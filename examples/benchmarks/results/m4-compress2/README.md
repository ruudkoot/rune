# Variable-width compression and shared-driver regression

Recorded 2026-10-16. Two imports bring the catalogue to 260 programs and
774 profiles. All 112 smoke/normal cases pass for both new dictionary variants
and both existing users of the extended shared compression driver, on every
Rune engine at both levels and all six managed native hosts. Eighteen semantic,
writer and demand checks pass all ten configurations at both levels. Sixteen
normal count samples pass the combined comparison with unchanged budgets.
Instrumentation times are separate from headline timings.

The port preserves the variable-width event protocol, persistent five-field
dictionary, six strict code-state fields and memoized byte-count feedback knot.
The eager-dictionary variant retains the causal delayed streams required for
that knot. Shared pair projections, unused payload non-demand, EOF behavior,
width markers and ratio/reset branches have explicit tests. Complete compressed
bytes are checked before the signed 64-bit nofib hash contributes to the sum.

All three original 500-iteration GHC runs match pinned stdout fixtures. Every
one of the 31 binary cut fixtures per profile agrees with all corresponding
original hashes. Source, input XML attribution, Makefile origin and absence of
individual program/input notices remain explicit. No license is inferred from
the data download URL. Full result forcing, source integer-width assumptions,
hash/aggregate semantics and changed output observation are documented.

The common driver accepts up to 500 repetitions; its existing selected profiles
and codec algorithms are unchanged. The fixed-12-bit codec remains a separate
implementation. No general .Z compatibility or larger untested full-dictionary
behavior is inferred from the selected fixtures. No prerequisite compiler/runtime
feature or universal large SML validation is claimed. M4 remains in progress.
