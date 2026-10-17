from pathlib import Path
import shutil
root=Path.cwd();p=root/'tests/out/benchmarks/bspt-originals';suite=root/'examples/benchmarks';out=suite/'results/m4-bspt'
assert (p/'acceptance.exit0').read_text().strip()=='0'
shutil.copy(p/'acceptance-wave.log',suite/'validation/oct17-bspt-1120-acceptance.log')
(out/'README.md').write_text('''# BSPT validation

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
''')
with(suite/'validation.md').open('a')as f:f.write('''
## Binary space partitioning modeller, 2026-10-17

Two ports bring the catalogue to 376 programs and 1120 profiles.
[Primary coverage](results/m4-bspt/coverage.tsv) records 55 passes in 56 cases:
all Rune cases pass, while ML Kit lazy smoke compilation reaches its unchanged
30-second limit. An isolated clean compiler probe confirms timeout status 124;
its normal-profile case passes. The original empty harness diagnostic remains.

All 1780 semantic assertions pass across twenty invocations. Eight normal count
samples agree, and six serial native smoke adapter samples pass separately.
Original full batch text, eleven interactive commands, signed-64 rational
operations and the GHC updatable batch thunk support exact correctness and
demand/sharing checks. Character comparison adds validation work to the original
hash consumer; globally shared geometry is computed once per fresh program.
[Complete evidence](results/m4-bspt/README.md) retains the profile limit,
consumer adaptations, source identities and unrecorded SML large checks.

[Full make JOBS=4 check](validation/oct17-bspt-1120-acceptance.log) exits zero
with 1120 profiles and all compiler/runedoc/runeopt cross-build comparisons.
M3, M4 and M5 remain in progress; M8 remains planned.
''')
with(suite/'literature.md').open('a')as f:f.write('''
## Binary space partitioning modeller

[Fuchs, Kedem and Naylor, On visible surface generation by a priori tree structures](https://doi.org/10.1145/800250.807481)
(1980) supplies partition-tree rendering context. Publisher-indexed bibliographic
information was checked; direct publisher retrieval failed. Do not infer this
paper authorship for nofib's two-dimensional modeller or claim its algorithms
are identical. The pinned program and GHC interface establish the specific
wrapped rational semantics, local par stub, seq demand and global batch sharing.
Compiler performance explanations remain hypotheses until separately measured.
''')
