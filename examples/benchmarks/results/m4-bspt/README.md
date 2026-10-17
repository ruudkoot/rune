# BSPT validation

Two ports bring the catalogue to 376 programs and 1120 profiles. Of 56 primary
smoke/normal cases, 55 pass. All 32 Rune cases and 23 native cases pass. ML Kit's
lazy smoke compilation exceeds the unchanged 30-second profile limit; the
isolated retry also fails. A clean direct compiler diagnostic returns timeout
status 124 after 30 seconds, with no executable. Its normal case passes under
the 600-second limit. Preserve that compile-timeout separately from incorrect
results and runtime failures; the initial harness diagnostic itself was empty.

Twenty semantic invocations pass all 89 checks each: 1780 passing assertions,
no failed or unreached assertions. All six managed SML hosts pass these checks.
Eight normal count samples agree across the applicable Rune engines. Six serial
single fresh-process native smoke adapter samples pass; these are diagnostics,
separate from count instrumentation and comparative performance claims.

The original GHC 9.4.7 program agrees with every supplied profile fixture.
An export-only observer records all 9761 batch bytes and eleven interactive
command outputs. Numeric observers cover wrapped signed-64 rational arithmetic,
noncanonical derived ordering and rounding ties. The source Prog interface
records the updatable global batch thunk. The port preserves that sharing,
left-subtree seq demand, the local sequential par stub and unused area roots.
Every repeated result is checked character by character and hashed. The extra
character comparison and bounded MGR command buffering are explicit adaptations.

Normal retains 25000 repetitions; large retains 125000. Smoke reduces FAST's
2500 repetitions to one. Geometry is computed once per fresh program and the
batch body persists across repeated in-process invocations. Full SML large
profile executions remain unrecorded. Earlier private snapshots and rational
sign annotations document development changes, not compiler defects; the final
canonical matrix uses the registered source identities.

Full DEBUGINFOD_URLS= make JOBS=4 check exits zero with 1120 profiles and all
compiler/runedoc/runeopt cross-build comparisons. Source identities, original
fixtures, complete process outputs and sample metadata accompany this report.
M3, M4 and M5 remain in progress; M8 remains planned.
