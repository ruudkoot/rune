from pathlib import Path
import shutil
root=Path.cwd();p=root/'tests/out/benchmarks/knights-originals';suite=root/'examples/benchmarks'
assert(p/'acceptance.exit0').read_text().strip()=='0'
shutil.copy(p/'acceptance-wave.log',suite/'validation/oct17-chess-1138-acceptance.log')
(suite/'results/m3-knights/README.md').write_text('''# Knight-tour validation

Four ports, together with the separately archived mate pair, bring the catalogue
to 382 programs and 1138 profiles. All 112 knights smoke/normal primary cases
pass across Rune O0/O2 engines and six managed native SML hosts. Twenty list-board
semantic invocations pass 42 assertions each; twenty array-board invocations pass
44 each: 1720 passes, no failures or unreached checks. Sixteen full normal Rune
count samples agree. Twelve serial single fresh-process native smoke adapter
samples pass separately from instrumentation and comparative performance claims.

Unmodified GHC matches all published list-board FAST/NORM/SLOW fixtures. Seven
full tours/cases per representation provide exact output oracles; independent
checks validate every closed tour's unique squares, bounds and legal jumps.
The array original's formatter overflows its stack on spaces 64 1 because its
base case is logTen 1 rather than zero. The reference selects the inactive array
module and applies exactly that formatter repair. The SML port preserves the
separate immutable array, render layout, deleteFirst metadata and indexTile
quirk. Complete original modules and the failing bounded diagnostic remain.

Numeric metadata/degree fields use explicit lazy and strict policies. Both retain
lazy frontiers and the unused first-square field; eager forcing of that field in
a deleted list singleton was an invalid draft adaptation and is corrected.
Memoization/persistence and incorrect-output controls pass. The original consumer
prints only rendered lengths; every port repetition additionally checks all
characters against original text and reports the checked total. Normal retains
100 repetitions on side fourteen; large retains 100 on side twenty. Smoke uses
one repetition on side eight rather than source FAST's hundred. Final SML large
repetition checks remain unrecorded; complete single-tour references are recorded.

All 96 inventory regressions and the five-pin 861-entry replay pass. The reviewed
Jonathan Hill README heading and inactive array variant are recorded explicitly.
Full make JOBS=4 check exits zero with 1138 profiles and all compiler/runedoc/runeopt
cross-build comparisons. Its complete repository transcript is linked from the
suite validation record. Historical draft failures are translation/test development
evidence, not host bugs; canonical source identities and results are separate.
''')
(suite/'results/m3-mate/README.md').write_text('''# Chess mating-search validation

Both ports pass all 56 primary smoke/normal cases across Rune O0/O2 engines and
six managed native SML hosts. Twenty semantic invocations pass all 48 assertions:
960 passes, no failures or unreached checks. Eight full normal Rune count samples
agree. Six serial single fresh-process native smoke adapter samples pass,
separately from instrumentation and comparative performance claims.

Original GHC matches every published FAST/NORM/SLOW output. Both SML policies
match those complete outputs in development calibrations; final registered-source
normal cases are separately validated by the canonical matrix. The selected
one-move simple smoke retains its own original 212-character result. Normal
Kohtz and large Holzhausen source problems are unchanged. Full final-source large
runs remain unrecorded; older complete calibration source/binary identities are
not presented as final canonical builds.

Nine original legal-move/updated-board cases and six small solutions cover pawn
promotion, pins, pawn threats, checkmate and stalemate. Other assertions exercise
source constructor order, stable natural mergesort, persistent boards, unused
opponent data, a winning alternative's unforced tail and incorrect-result
rejection. Lazy generation and eager finite legal-move lists share the source
AND–OR stopping rules and complete compact reply rendering. The consumer buffers
and validates the complete output rather than writing it to stdout.

Initial private relative-path, record-selector typing and invalid poison-probe
failures are retained as development evidence. Portable pair annotations and the
reviewed attacking-fold helper precede all final canonical checks; no host-specific
workaround or compiler/runtime feature is added. Dataset composition credits and
individual file comments remain with the original source snapshot.

Full make JOBS=4 check exits zero with 1138 profiles and all compiler/runedoc/runeopt
cross-build comparisons. Complete process outputs, samples, source/input identities
and the linked acceptance transcript distinguish passing evidence from unrecorded
large-profile work. M3/M4/M5 remain in progress and M8 remains planned.
''')
with(suite/'validation.md').open('a')as f:f.write('''
## Knight tours and mating search, 2026-10-17

Six ports bring the catalogue to 382 programs and 1138 profiles.
[Knights coverage](results/m3-knights/coverage.tsv) records 112/112 passing
primary cases; [mate coverage](results/m3-mate/coverage.tsv) records 56/56.
All Rune O0/O2 engines and all six managed native hosts pass. The semantic
ledgers record 1720 passing knight-tour assertions and 960 mating-search
assertions, with no failed or unreached checks.

All 24 normal count samples agree, and 18 serial single fresh-process native
smoke adapter samples pass separately. Complete original tour/solution text,
independent closed-tour legality, legal-move fixtures and demand/persistence
controls validate both evaluation styles. The inactive array board remains a
separate representation with its reviewed formatter repair and original bounded
failure; exact output validation adds work to the original length consumer.

All 96 inventory regressions and the five-pin 861-entry replay pass, recording
Jonathan Hill's attribution and the twenty-seventh supplementary variant.
[Knights evidence](results/m3-knights/README.md) and
[mate evidence](results/m3-mate/README.md) retain original notices, input origins,
source identities, complete attempts, development failures and unrecorded final
large-profile runs.

[Full make JOBS=4 check](validation/oct17-chess-1138-acceptance.log) exits zero
with 1138 profiles and all compiler/runedoc/runeopt cross-build comparisons.
M3, M4 and M5 remain in progress; M8 remains planned.
''')
