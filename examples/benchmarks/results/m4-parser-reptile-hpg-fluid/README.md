# Parser, Reptile, HPG and Fluid validation, 2026-10-19

Eight application ports increase the catalogue to 503 programs and 1461
profiles. Each application has separately named lazy and strict finite
data, original fixed input parameters, complete output references, source
identities, program and dataset notices, and documented translation choices.
M4 remains in progress: Anna and Veritas are not registered imports.

| Gate | Recorded outcome |
|---|---|
| Smoke and normal correctness | 209 of 224 combinations pass; all 128 Rune combinations pass across four engines and O0/O2. |
| Native hosts | All Parser combinations pass. Three ML Kit smoke compiles exceed the unchanged 30-second allowance. Twelve SML/NJ combinations fail. |
| Semantics | 52 complete groups pass; four SML/NJ groups remain incomplete. There are 392279 passing and 10 failing assertions. |
| Normal allocation counts | All 32 samples agree across applicable Rune engines; eight unchanged process-tree guards exit zero without intervention. |
| Serial native adapters | 20 fresh samples pass; four legacy SML/NJ preflights are rejected and provide no accepted timings. All 24 native compilations pass. |
| Repository acceptance | make JOBS=4 check exits zero after 1883.9 seconds, including all 498 compiler comparisons and seven-host runedoc/runeopt agreement. |
| Discovery and native-status regressions | All 160 inventory tests and four planted native compile-error/timeout cases pass. |

[Correctness outcomes](correctness.tsv) retain each profile, configuration,
failure category and raw artifact directory. O0/O2 apply to Rune; native
hosts use host-default options once. Defaults remain 30 seconds/1 GiB for
smoke, 600 seconds/4 GiB for normal, 3600 seconds/8 GiB for large. There is
no profile-limit increase. Complete large reports were checked against the
originals in private reference probes; no complete large host matrix is claimed.

## Independent references and source fidelity

Parser preserves lazy token positions, the cyclic EOF stream, original
combinators and complete AST/Show output across the three pinned inputs,
with 500 parses per profile. Reptile preserves the rational geometry and
interactive tiling-editor script protocol, all six input scripts, state
transitions and 500 repetitions; it does not require a graphics server.
HPG preserves its binary32 Wichmann-Hill operations, source seed stream,
shared character-list name supplies, generator state and all three output
chunks for every profile, with 100 repetitions.
Fluid preserves sparse radix tries, ordering, assembly, factorization,
iteration and binary32 arithmetic. Its dataset is reopened every repetition.
The complete 814-byte report agrees exactly; 10015 floating-point printing
vectors include subnormals and signed zero. Fluid profiles retain 35/350/1750
repetitions. Individual provenance documents distinguish source credits,
algorithm references and missing or ambiguous notices.

The reference-observers directory retains original GHC sources, observers,
full reports and stage comparisons. Expected results come from the pinned
Haskell programs, not from portable output copied into an oracle.
Source parser quirks, HPG prefix demand and shared names, and Fluid unused
computations are preserved. Portable type annotations close pairs and
integer/real types required by Standard ML; they do not replace an algorithm.

## Host failures and semantic epochs

Four HPG legacy SML/NJ profile combinations fail result checks. Fluid legacy
SML/NJ has two incorrect report hashes; Fluid strict loading terminates with
a bogus-overflow SIG11 on legacy, 32-bit and development SML/NJ, in both
profiles. The six strict failures are runtime failures during interactive
loading, not demonstrated memory-limit failures. Three ML Kit smoke compiles
time out. Normal ML Kit profiles pass.

[Canonical semantic groups](semantics.tsv) and [all 73 raw groups](semantic-attempts.tsv)
retain every attempt. Parser's three initial SML/NJ test compiles needed a
closed token type on the deliberately failing lexer column. Only those three
groups were retried; every canonical Parser group passes all 204 assertions.
Reptile passes 50 assertions per group. HPG has thirteen complete groups of
20032 checks; its partial legacy group records one pass followed by
ExnDuringExecution, with no summary.

Fluid's final test harness shares one pure kernel instance per evaluation
policy, preserving all 11316 assertions and the external constructor-unpacking
boundary. All fourteen groups were rerun after this test-only change. Eleven
groups pass completely. Legacy SML/NJ records 1271 passes and nine failures,
32-bit records 1279 passes and one failure, and development records 1280
passes before a fatal signal. None reaches a summary. The existing
[real-pair report](../../../../docs/bugreport/smlnj/Datatype/real-pair-through-type-constructor/BUGREPORT.md)
describes a related constructor-boundary defect; it does not establish the
root cause of every observed failure. Assertions not reached are incomplete.

The acceptance-subject hashes precede the two test-only changes. Benchmark
kernels, manifest and tooling are unchanged between those gates and final
canonical checks. Both test epochs remain archived. No incorrect result
contributes an accepted timing.

## Measurement and tooling

Fresh serial runs use one sample to validate adapter execution. They are not
headline performance comparisons, warmup claims or median/IQR reports.
Original and final portable-type epochs remain separate. SML/NJ exported
images may perform eager declaration initialization during compilation;
compile and execution phases must be interpreted separately.

The shared native runner now captures real MLton/ML Kit compile exits before
returning, including exit 124 and explicit timeout markers. ML Kit's
typecheck-only path records its effective eight-times timeout correctly.
Four independent fake-host compile-error/timeout regressions exercise the
status fields. This closes the status-capture follow-up discovered in the
Happy wave; other M8 coverage and maintenance work remains open.

Final catalogue, bounded smoke and documentation checks pass after metadata updates;
all 160 inventory regressions pass. The final metadata exit record is retained.
