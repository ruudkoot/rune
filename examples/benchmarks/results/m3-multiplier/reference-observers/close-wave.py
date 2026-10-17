from pathlib import Path
import shutil
root=Path.cwd();p=root/'tests/out/benchmarks/multiplier-originals';suite=root/'examples/benchmarks'
assert(p/'acceptance.exit0').read_text().strip()=='0'
shutil.copy(p/'acceptance-wave.log',suite/'validation/oct17-expert-regex-multiplier-1159-acceptance.log')
reports={
'm3-expert':'''# Expert-system validation

Both ports pass all 56 primary smoke/normal cases across Rune O0/O2 engines and
six managed native SML hosts. Twenty semantic invocations pass all 45 assertions:
900 passing assertions, none failed or unreached. Eight full normal count samples
agree. Six serial single fresh-process native smoke adapter samples pass,
separately from instrumentation and comparative performance claims.

Original GHC matches all FAST/NORM/SLOW length fixtures, while export-only
observers record the complete source dialog and five additional answer scenarios.
All selected dialogs, unification/occurs behavior, table operations and lazy
feedback checks pass. Only lowercase no is negative. A question is emitted before
its answer is looked up, and replies after a negative More answer remain unused.
The strict variant eagerly demands finite phrase children; both preserve feedback
control laziness. The source's shared question string and table algorithms remain.

Normal retains 10000 repetitions and source i+9999 input prefixes. Smoke reduces
FAST's 1000 repetitions to one. Exact per-character validation adds work to the
source length consumer. Full SML large repetition runs remain unrecorded; original
large fixture validation is recorded. Ian Holyer's March 1993 attribution and the
1999 shared-string comment are preserved with all original sources and inputs.

The shared full repository acceptance transcript exits zero with 1159 profiles
and all compiler/runedoc/runeopt cross-build comparisons. Complete raw results,
source/input identities and resource metadata accompany this report. M3/M4/M5
remain in progress and M8 remains planned.
''',
'm5-regexredux2':'''# Regex-redux validation

The port passes all 28 primary smoke/normal cases across Rune O0/O2 engines and
six managed native SML hosts. Twenty semantic invocations pass all 23 assertions:
460 passing assertions, none failed or unreached. Four full normal count samples
agree. Three serial single fresh-process native smoke adapter samples pass,
separately from instrumentation and comparative performance claims.

Pinned OCaml fasta3 generates deterministic inputs at N=100, 50000 and 500000.
These explicit smaller profiles retain source RNG state, probabilities and line
widths; the published N=5000000 input is not claimed. Original OCaml 4.14.1 yields
all expected reports. A development Rune O2 pilot validates all three, including
large; final registered-source canonical checks cover smoke and normal. The
public program's added notice is recorded separately from that earlier source.

Twelve original Str observations and five complete original program edge cases
cover greedy matching, ordered alternatives, anchors, overlap, case and ordered
substitutions. The portable matching adapter implements only the fixed source
fragment; it is explicitly a library replacement rather than OCaml Str's internal
engine. Pattern-at-a-time searches and replacement order remain unchanged. Full
stdout is validated and replaced by a checked-length report. Data identities,
original programs, generator credits and Revised BSD notices are retained.

All 102 inventory regressions and the five-pin 861-entry replay pass. Roman
Kashitsyn's Bytes adaptation credit is recorded. The shared full repository
acceptance transcript exits zero with 1159 profiles and all cross-build tool
comparisons. This does not close remaining Sandmark or standard-library work.
''',
'm3-multiplier':'''# Stream multiplier validation

All four trace/count variants pass all 112 primary smoke/normal cases across Rune
O0/O2 engines and six managed native SML hosts. Twenty semantic invocations pass
all 56 assertions: 1120 passing assertions, none failed or unreached. Sixteen full
normal count samples agree. Twelve serial single fresh-process native smoke
adapter samples pass, separately from instrumentation and performance claims.

Unmodified GHC matches every FAST/NORM/SLOW fixture at 32, 256 and 512 input bits
and 2000 clocks. Eight export-only trace/count observations agree with an
independent masked shift/add clock model. Small-width truncation, clock ordering,
truth tables, signed-64 conversion and strictness checks pass. Lazy binary heads
preserve the active source lift21; strict heads correspond to its commented
alternative. Both retain unary headstrict, latches, recursive wire sharing,
delayed word arguments/tails, adder pairing and spine-only wide-gate length.

The inactive runMult consumer is a separate pair of programs. It sums ready bits
and leaves the product stream pending, as the demand control demonstrates; it is
not described as forcing the whole product calculation. Normal/large sums are
222, smoke is three. Trace variants check all original characters. Normal and
large keep source widths/cycles; smoke reduces FAST to sixteen clocks. Full final
SML large runs remain unrecorded. Earlier complete normal pilots and recursive-
forcing failures are labelled development evidence, separate from final source
identities and canonical results. No compiler/runtime feature is added.

Source authorship/copyright and the count-consumer supplementary inventory entry
are recorded. All 102 inventory regressions and five-pin replay pass. The shared
full make JOBS=4 check transcript exits zero with 1159 profiles and all compiler,
runedoc and runeopt cross-build comparisons. Outstanding source imports remain
scheduled; M3/M4/M5 are in progress and M8 remains planned.
'''}
for group,body in reports.items():(suite/'results'/group/'README.md').write_text(body)
with(suite/'validation.md').open('a')as f:f.write('''
## Expert feedback, regex-redux and stream multiplier, 2026-10-17

Seven ports bring the catalogue to 389 programs and 1159 profiles.
[Expert coverage](results/m3-expert/coverage.tsv) records 56/56 passes,
[regex-redux coverage](results/m5-regexredux2/coverage.tsv) 28/28 and
[multiplier coverage](results/m3-multiplier/coverage.tsv) 112/112. All Rune O0/O2
engines and six managed native SML hosts pass. The semantic ledgers record
900 expert, 460 regex and 1120 multiplier passing assertions, none failed or
unreached. All 28 normal count samples agree; 21 serial single fresh-process
native smoke adapter samples pass separately from instrumentation.

Original dialogs, regex-library observations, complete reports/traces and an
independent multiplier clock model support correctness. Explicit demand tests
cover question/answer feedback, unused replies, phrase policies, gate strictness,
word arguments/tails and the count consumer's undemanded product stream. Fixed
profile reductions, consumer validation costs, portable regex library replacement,
source arithmetic widths and unrecorded final large runs are documented.

All 102 inventory regressions and five-pin 861-entry replay pass. Holyer,
O'Donnell and Kashitsyn credits are recorded, with the twenty-eighth supplementary
variant preserving multiplier's count-only consumer. Complete
[expert](results/m3-expert/README.md), [regex-redux](results/m5-regexredux2/README.md)
and [multiplier](results/m3-multiplier/README.md) evidence retains notices,
input/source identities, raw samples and development failures separately.

[Full make JOBS=4 check](validation/oct17-expert-regex-multiplier-1159-acceptance.log)
exits zero with 1159 profiles and all compiler/runedoc/runeopt cross-build
comparisons. M3/M4/M5 remain in progress; M8 remains planned.
''')
