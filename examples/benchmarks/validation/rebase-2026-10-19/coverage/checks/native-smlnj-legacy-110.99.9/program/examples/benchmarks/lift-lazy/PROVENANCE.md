# lift-lazy provenance

### Algorithm and workload

Transform a fixed nested functional-language AST with both a plain lambda
lifter and a modular fully-lazy lambda lifter, then pretty-print the input
and both supercombinator programs. Preserve free-variable analysis,
abstraction, lambda separation, binding-level annotation, maximal-free-
expression identification, renaming, floating and final lambda lifting.
Both algorithms run in every iteration, matching the original driver.

### History, authorship, variants and notices

[nofib real/lift](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/lift)
is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. LambdaLift.lhs is the executable literate paper
*A modular fully-lazy lambda lifter in Haskell*, by Simon L. Peyton Jones
and David Lester. Its title/author block and complete prose/code are retained,
together with Utilities, Print, Test, Main, the modern NofibUtils adapter,
Makefile and all FAST/NORM/SLOW golden outputs. No additional individual
permission grant is inferred from the author block or from a helper.

The paper separates full-laziness transformation from lambda lifting.
This is algorithmic full laziness, distinct from the port's evaluation-policy
suffix. Both lift-lazy and lift-strict execute both source transformations.
They differ in finite intermediate AST/annotation materialization; they do
not denote plain versus fully-lazy algorithms.

### Translation and semantic decisions

Keep parameterized AST/annotation datatypes, list-based sorted name sets,
source quicksort/dedup and ordered union/difference, association-list
environments, list-backed bags, body-first supercombinator collection and
source definition/name-supply order. No replacement optimizer or parser
generates the result. Test.hs supplies the fixed AST; the portable
constructor transcription is checked against the complete original AST.

Both policies use explicit memoized AST/name/annotation/supply delays.
The strict policy traverses finite results at pass boundaries; the lazy
policy leaves them demand-driven. Recursive let renaming ties the
extended environment through deferred name cells, installing fresh names
before they are demanded. Strict traversal occurs after that knot is ready.
This source-level support requires no compiler or runtime extension.

The source lambda-renaming branch returns the supply after its arguments,
rather than the later supply returned from its body. Preserve and test
that behavior; do not silently repair it or claim the observed examples
prove a general naming theorem for arbitrary inputs.

Retain arbitrary-precision integer literals with IntInf. Selected name,
level, repetition and byte counts fit signed 31-bit integers. Replace the
host-width hash with explicit modular Word64 arithmetic, reproducing the
original 64-bit GHC outputs even on 32-bit SML hosts.

Preserve higher-order Iseq/Oseq printers, delayed expression inspection,
pending indentation after newlines, restored outer indentation, definition
order and complete textual output. Numeric literal formatting explicitly
uses Haskell's minus spelling.

The original Test.program is a shared top-level value. The portable driver
creates one memoized input root per invocation and shares it across all
iterations; zero repetitions do not force it. CLI/reference reads move
outside the loop. The GHC NOINLINE salt IO barrier has no portable SML
equivalent and is not claimed; source specialization/loop motion remains
a compiler concern.

### Inputs, profiles and validation

| Profile | Iterations | Input |
|---|---:|---|
| Smoke | 1 | Fixed original Test.program AST |
| Normal | 4000 | Same fixed AST |
| Large | 20000 | Same fixed AST |

Normal and large preserve NORM/SLOW repetition counts; smoke explicitly
reduces the source FAST count of 400. Each iteration validates the entire
1948-byte input/plain/fully-lazy report and modular hash
0x8a2cd0a394a3204d. It returns validated iteration/byte counts rather than
printing one signed hash per iteration. A failed complete result or hash
is rejected before accepting measurement data.

Read-only GHC observers record all input/plain/full ASTs for seven cases:
identity, captured variables, nested arguments, shadowing, an unused
recursive cycle, factorial and the fixed source program. Both policies
must match all complete structures and the exact source pretty output.
A separate memoized Python evaluator checks six terminating cases, including
factorial 720, before and after each transformation; it also checks scoped,
closed, lambda-free supercombinator programs. The fixed source program is
structurally validated, not claimed to terminate under that evaluator.

Direct tests cover shared node/name demand, strict pass boundaries,
recursive renaming knots, the source returned-supply quirk, name sets,
large integer literals, delayed printing, indentation, zero work and
deliberately incorrect reports/hashes.

An earlier ML Kit auxiliary region-analysis crash is preserved separately.
Both complete normal applications and equivalent explicit fixed-case calls
pass. The final common semantic target retains all assertions and passes on
all six managed hosts and every Rune configuration; the benchmark kernel
contains no host-specific workaround.

### Compiler/runtime questions and evidence limits

Investigate higher-order printer composition, recursive AST allocation,
annotation sharing, environment lookups, repeated analyses and pass-boundary
materialization. These are source-based hypotheses. Count and timing
evidence must identify input/policy/configuration; cross-language salt,
fusion, allocation and constant specialization are not assumed equal.

### Literature and review scope

The full primary executable paper is reviewed in the pinned LambdaLift.lhs,
including its abstract, introduction and algorithm code. It explicitly
presents full laziness as a separate pass and discusses let/letrec handling.
The maintained nofib source and previously reviewed Partain suite paper
supply collection context. Complete original observations and the independent
evaluator support the recorded cases; they do not prove general equivalence
for every AST or establish a compiler performance mechanism.
