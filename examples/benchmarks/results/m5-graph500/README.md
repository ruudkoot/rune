# Sequential Graph500 validation

Three ports bring the catalogue to 370 programs and 1102 profiles.
Of 84 primary smoke/normal cases, 70 pass and fourteen fail.
Efficient generation records 23 passes/five failures, kernel 1 records
25/three, and the append-based prototype records 22/six.
All 48 Rune cases and every MLton/ML Kit primary case pass.

Twenty 312-check semantic invocations record 5606 passes, twelve failed
assertions and 622 unreached checks. Legacy 32-bit SML/NJ stops after the first
failed generation assertion and cannot decode the original header. Legacy
64-bit SML/NJ has one or three failures in the two compilation contexts; the
development version has one each, and Poly/ML has two each. All other semantic
invocations pass every check.

Twelve complete normal count samples agree under Rune's engine model rules.
Seven serial single fresh-process native adapter samples pass; two correctness
prechecks fail and supply no accepted sample. These are adapter diagnostics,
with default sampling and existing count budgets unchanged.

The original efficient generator's selected output files and all three prototype
CSV outputs match portable Rune output byte-for-byte. Original kernel 1 agrees
with an independent decoder/adjacency model on every profile. Selected normal
and large Rune pilots pass in a recorded 1-GiB guard. Full larger published
parameter sets remain explicit additional candidates rather than claimed checks.

Standalone controls identify a source power/truncation sensitivity on SML/NJ,
Poly/ML exact-integral nearest-conversion differences and a legacy 32-bit SML/NJ
word-construction discrepancy. Additional legacy 64-bit normal hashes and
compilation-context edge/adjacency failures remain unexplained. No host-specific
arithmetic, string-parsing replacement of the valid literal, integer replacement
of source floating power or tolerance change is introduced.

Original code, interfaces, stdlib notices, fixed state origins and exact binary
data identities remain. Binary edge fixtures are narrowly reviewed source data;
compiled artifacts and execution caches are excluded. A single portable finite
binary64 codec avoids differing optional API availability across hosts.

The old measurement classifier labels Poly/ML's quoted Fail message as a runtime
failure. Original samples retain that recorded status; the separate reviewed
disposition table identifies the explicit incorrect-result precheck. This label
does not admit timing samples and is covered by the immediate tooling follow-up.

All 90 existing inventory regressions pass. Full make JOBS=4 check exits zero
with 1102 profiles, 498-program bytecode agreement and matching runedoc/runeopt
builds. validation.md links the complete transcript. M5 remains in progress.
