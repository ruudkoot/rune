# Event-driven circuit validation

Both ports pass all 56 primary smoke/normal cases across Rune O0/O2 engines and
six managed native SML hosts. Twenty semantic invocations pass all 72 assertions:
1440 passing assertions, none failed or unreached. Eight full normal Rune count
samples agree. Six serial single fresh-process native smoke adapter samples pass,
separately from instrumentation and comparative performance claims.

Unmodified GHC matches all FAST/NORM/SLOW fixtures. Twelve boundary states and
complete changed-event sequences match both the original export observer and an
independent stable-heap simulator. Dependency tables, NAND short-circuiting,
existing-event tie priority, scheduling-time state snapshots, exclusive cutoffs
and both state-update passes are retained. Source miraseq is a no-op; finite
strict lists are a separately named evaluation policy. Global clock/dependency
sharing persists across repetitions while simulation state stays fresh.

Normal retains 100 runs at horizon 100000; large retains 100 at 500000. Smoke
reduces FAST's hundred runs at 10000 to one at 200. Every final state/newline is
validated, with a stable repetition/character/state report. Full final SML large
repetition runs remain unrecorded. Complete original sources, parent compatibility
shim, fixtures, independent model, process outputs and source identities remain.

Full make JOBS=4 check exits zero with 1171 profiles and all compiler/runedoc/
runeopt cross-build comparisons. The shared transcript is linked from suite
validation. M3/M4/M5 remain in progress and M8 remains planned.
