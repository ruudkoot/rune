# Mini Prolog application variants

All 112 primary smoke/normal cases pass: four variants, Rune's four engines at
O0/O2 and six native hosts at defaults. All twenty auxiliary invocations pass
111 assertions, totaling 2220. Sixteen full normal count samples agree under
Rune's execution-model rules, including allocation across all four engines.
Budget files remain unchanged.

Twelve serial single fresh-process native smoke samples pass after correctness
prechecks. They validate adapters separately from instrumentation and do not
replace the default ten-sample performance study. Complete configurations,
samples, settings, inputs, source identities and transcripts are retained.

Unmodified GHC runs match all three active-engine stdout fixtures exactly.
Engine.hs and StackEngine.hs are byte-identical at the pin. The alternate
PureEngine.hs reference selects that module instead, keeping the fixed Version
module unchanged; its sign-on label still says stack based. Its own exported
loop transcripts differ because it lacks cut. The two algorithms are separate
benchmarks, each with lazy and strict finite term payloads.

Export-only original-loop observers supply all three complete reference
transcripts for each engine. Both SML policies agree on every character.
Eleven additional command cases per engine cover backspaces, aliases, arity,
empty names/queries, variable printing, cut and quit-tail behavior. Direct
tests exercise parser alternatives/order, function-valued substitution
composition, occurs checks, variable renaming, cut frames, negative transcript
checks, modular hashes and finite payload demand.

The source list-of-successes parser, sorted predicate database, insertion order,
function substitutions, explicit stack or memoized proof tree, lazy search
control and higher-order difference-list printers remain. Input/library data
are shared across repetitions, while each interpretation builds fresh parser,
term and search state. The driver validates every character while computing
the source-width Word64 hash; an independent reverse polynomial checks it.
Normal retains all 200 repetitions and exact upstream command data.

The full four-variant normal calibration passes on final-source Rune O2 within
its recorded 600-second/RSS guard. Every large transcript passes one complete
interpretation under all auxiliary configurations; full 200-iteration large SML
validation remains unrecorded. The fixture bytes intentionally retain trailing
prompt spaces and backspaces; Git whitespace exemptions cover only raw data
and evidence, not the portable SML.

Initial private host checks exposed a string-comparison annotation and incorrect
fixture working directories. Their failed logs remain alongside corrected
checks; they are not counted as canonical successes. Compiled executables,
bytecode, heaps, object files and compiler caches are excluded.

All 74 inventory regressions pass. Five clean pinned trees reproduce all 861
entries, with only the Prolog authorship/evidence row updated. The supplementary
variant inventory records the exact StackEngine duplicate and distinct
PureEngine import with identities, authorship and notice review.

To recreate the references, restore the archived scripts under
tests/out/benchmarks/prolog-originals with the pinned nofib checkout under
tests/out/benchmarks/pinned/nofib. Run reference.py, rebuild the archived
Program/Observer modules for each engine, and run extra.py. GHC 9.4.7 produced
the recorded fixtures. The benchmark provenance distinguishes the original
source credits, the university bibliographic record and unreviewed chapter
contents.

Full make check exits 0 with 1024 catalogue profiles; validation.md links the
complete transcript. M4 remains in progress.
