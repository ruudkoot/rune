# Chess mating-search validation

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
