# Hartel wave4main validation

Both finite-data policies pass all 56 canonical smoke/normal cases on Rune
O0/O2 stack, register, JIT and native engines and all six managed SML hosts.
All twenty semantic invocations complete thirty assertions: 600 pass, none
failed or unreached. Native O0/O2 labels repeat host-default compiler settings.

Original observers record nine full states through 400 steps, with six array
domains and 208 cells per state. An independent unsplit-grid stencil agrees
on all 1872 original values. Both policies check finite cell values within
1e-10 absolute plus 1e-10 relative error, exact bounds and the original
formatted checksum. Perturbation, NaN and mismatched-step controls reject
incorrect results. Boundary poison tests, memoized cells, strict
materialization and border-index checks exercise the translation decisions.

Normal retains 500 repetitions of eighty steps. Smoke reduces the source
500 repetitions to one at eight steps. Large retains 500-by-400; nine-state
semantic evidence includes one 400-step solution per policy but is not a
recorded full large-profile run. Full numeric validation adds traversal and
retention before the original formatter, as stated in provenance.

All eight full-normal Rune count samples agree under the existing instruction
and allocation comparison rules. Both guards exit zero without interruption.
Six serial single fresh-process native smoke diagnostics pass before heavy
validation. These are adapter diagnostics, not ten-sample comparative claims.

Public semantic shell targets, all 114 inventory regressions and the five-pin
861-entry replay pass. An intermediate source-order failure remains separate
development evidence. Source identities and original notices/attribution limits
are retained. Full make JOBS=4 check exits zero with 1337 profiles, including
all compiler, runedoc and runeopt cross-build comparisons.
