from pathlib import Path
import json,csv,collections
root=Path.cwd();suite=root/'examples/benchmarks';out=suite/'results/m4-veritas';p=Path(__file__).resolve().parent
s=json.loads((out/'summary.json').read_text());rows=list(csv.DictReader((out/'correctness.tsv').open(),delimiter='\t'))
failures=collections.Counter(r['status']for r in rows if r['status']!='pass')
text=f"""# Veritas application closure, 2026-10-19

The lazy and strict Veritas ports close M4: all 34 suitable nofib real
application paths now have implemented profiles. The catalogue contains 507
programs and 1473 profiles. The remaining real application entry has an
explicit facility blocker in the pinned inventory.

| Gate | Recorded outcome |
|---|---|
| Smoke and normal profiles | {s['profile_pass']} of 56 combinations pass; all 32 Rune combinations pass across four engines and O0/O2. |
| Semantics | Thirteen complete groups each pass 218 assertions; ML Kit reaches its 600-second compile deadline without assertions. |
| Normal allocation counts | All eight samples agree; the unchanged 2-GiB process-tree guards finish without intervention and retain the 8-GiB available-memory floor. |
| Final native adapter diagnostics | Two Poly/ML fresh samples pass; two MLton and two legacy SML/NJ compiles exceed 30 seconds and supply no accepted timings. |
| Repository acceptance | make JOBS=4 check exits zero after {s['acceptance']['elapsed_seconds']:.1f} seconds. |

[Profile outcomes](correctness.tsv) identify every configuration and artifact.
Native hosts use host-default flags; level labels describe Rune.
Nonpassing profile categories are {', '.join(str(v)+' '+k for k,v in sorted(failures.items()))}.
Default limits remain unchanged: smoke 30 seconds/1 GiB, normal
600 seconds/4 GiB, large 3600 seconds/8 GiB. No complete large host matrix
or whole-suite compiler ranking is claimed.

## Independent original observations

The pinned GHC program repeats the same supplied GRIP editor input 400,
4000 and 20000 times. Every complete output line is checked. The 1391-byte
request stream has SHA-256
91ae6ea6fb1188a5f90e69bdaeb0f7c3d3b5d5d6f1bf6141db14f1883bbe5865
and the signed source hash -3665993109681513221. Input, hash, original
observers and complete observations remain in [reference-observers](reference-observers/).

Independent fixtures cover 26 protocol/demand cases, 14 lexical/parser inputs
at both stages and 25 editor scripts with both request bytes and complete
proof-editor outcomes. Two evaluation policies agree on all fixtures. Ten
additional assertions check the complete/signed hash, zero/negative work,
skipped input and rejected results. The 218-check group runs against fresh
fixtures rather than a captured transcript substituted for the algorithm.

The proof probes caught an actual development-port error: attribute
replacement retained the old attributes. Its failed source epoch remains in
the archive. Normal timed request bytes alone had not exposed it. Other
retained epochs show a parser-observer layout error, incomplete proof-outcome
capture and driver handling of the '-' integer spelling.

The selected port preserves the source's documented partial functions,
stubbed database restoration, equality/conditional oddities and tactic
behavior. Agreement is evidence of this benchmark translation; it does not
certify the original prover's logical soundness. The benchmark is a pure
editor/action-state workload and does not require a GUI, FFI or effect
handlers. Selected small indices fit a 31-bit SML int; the source hash uses
explicit Word64 operations and IntInf only for signed decimal formatting.

## Fixture transport correction

The first semantic launch omitted nested cases/FILES from its copied
fixture list. Ten groups completed 54 assertions and then stopped on input.
Their [raw attempts](semantic-attempts.tsv) remain incomplete. The correction
changes fixture transport only. All eight affected Rune groups and both
affected MLton/legacy SML/NJ groups were rerun successfully.

The canonical [semantic ledger](semantics.tsv) combines those ten corrected
groups with the original three complete SML/NJ32/development/Poly/ML groups
and the ML Kit compile timeout. It records 2834 passing assertions and no
failed assertions. All 24 raw groups remain available with their actual
fixture epochs. No interrupted group is converted into a pass.

## Reproduction and evidence

Run make bench-check with BENCH_FILTER=veritas-, smoke or normal and the
selected configurations, setting RUNE_BENCH_COMPILE_OPTIONS to -O0 or -O2.
Run sh tests/benchmarks/check-nofib-veritas.sh for the independent checks.
Run make bench-count with the same filter for normal allocation comparisons.
Serial native diagnostics use make bench with BENCH_SAMPLES=1 and
BENCH_MODE=fresh; they are adapter checks, not headline performance samples.

[Validation drivers](validation-drivers/) retain subjects, commands, exit
codes, guards, all profile logs and the parser-pair/fixture correction epochs.
[Counts](counts/) and [fresh adapter diagnostics](fresh-adapter-diagnostics/)
keep complete metadata, source/input snapshots and streams. The earlier
native parser-pair source failure remains separate from final-source results.

The [acceptance transcript](acceptance.log) and [subject](acceptance-subject.json)
record the full repository check. A later metadata-only compiler-override
provenance change and fixture-transport regression check are validated
separately in the M8 closure evidence. No compiler or runtime feature changes
are introduced by either milestone.

Readable raw files are retained even below ignored build directories.
Compiled/executable/cache payloads stay excluded. Binary protocol observations
are represented losslessly as ASCII hexadecimal, with original identities;
no binary-payload policy exception is added.
"""
(out/'README.md').write_text(text)
