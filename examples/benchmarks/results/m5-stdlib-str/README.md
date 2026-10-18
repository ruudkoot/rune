# stdlib-str validation

6 selectors pass all 168 primary smoke/normal cases on Rune
O0/O2 across stack, register, JIT and native engines, plus six managed native
SML hosts. Native optimization groups use host-default compiler settings.

All twenty semantic invocations pass their complete targets: 840
passing assertions, none failed or unreached. Their private invocation paths
are retained accurately; imported kernel bytes match those final subjects.
The generated public semantic shell targets also pass Rune O0/O2, confirming
their source order and working-directory/data contract.

Eighteen edge-count and fourteen selected original selector results agree
with independent literal models. Twenty-one further original Str observations
cover partial prefixes, offsets, repeated replacements, empty-field splitting
and match-result state. Compile scope remains per iteration for str_regexp and
per call for the other selectors. The portable regex engine is an explicit
library replacement rather than a claim of identical native engine costs.

24 full-normal Rune count samples agree under the suite's instruction/
allocation comparison conventions. All guards exit zero without interruption.
18 serial single fresh-process native smoke samples pass before the heavy
validation jobs. These are adapter diagnostics, not ten-sample comparative
performance claims. Default headline sample counts and modes remain unchanged.

Complete selected benchmark/library sources, run plans, notices, dependency
identities, original observers, independent models and raw results are retained.
The Sandmark Unlicense and OCaml LGPL/linking-exception grants remain separate.
Normal reductions and selected large profiles are documented per selector;
full final SML large repetitions remain unrecorded.

Count logs initially used reversed child-output/guard-summary filenames. Their
names were normalized to the archive convention; original samples, JSON guard
records and source identities are unchanged. No measurement was rerun for this
log-routing correction. The full repository acceptance run exits zero
with 1316 profiles and all compiler/runedoc/runeopt cross-build comparisons.
