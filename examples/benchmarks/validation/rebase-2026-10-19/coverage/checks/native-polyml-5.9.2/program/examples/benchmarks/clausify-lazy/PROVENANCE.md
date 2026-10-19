# clausify-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/clausify`.
Retain Main.hs, Makefile, the three stdout fixtures and SHA-256 identities.
The source credits Colin Runciman (York, 18 October 1990), David Wakeling's
February 1992 batch driver, and Runciman's corrected ordered insertion
(3 May 1994). Its retained March 1992 message describes earlier versions in
several functional languages. No individual redistribution grant is stated;
the authorship/history header is preserved without inventing a license.
Inputs are the embedded proposition literal; no external dataset is acquired.

## Algorithm, history and variants

Parse a propositional expression with right-associative equal-precedence
operators, eliminate implication/equivalence, push negations inward, distribute
disjunction over conjunction, split clauses, sort/deduplicate literals, remove
tautologies and sort/deduplicate the remaining clauses. Preserve the original
pattern order, including testing a disjunction's right child for conjunction
before its left. Equivalence expansion retains the same input subtree sharing;
separate recursive elimination calls are not replaced by a shared transformed
subtree or a truth-table solver. The unique clause ordering is lexicographic on
positive and then negative symbol lists.

Both named variants share one SML97 functor. Need memoizes formula headers and
fields, sequence spines/heads, clause pairs and recursive rewrite results.
Strict eagerly constructs the corresponding finite structures. Deferred right
branches, clause-field comparisons, insertion tails and tautology checks retain
the source's short-circuit behavior in Need. Symbol characters are atomic.
The parser uses an eager finite token/stack list in both variants; formula
children remain suspended in Need. Parsing must consume the complete selected
input before its final stack pattern can deliver the formula. This explicit
parser representation does not claim a portable Haskell closure layout.

The source's infinite shared spaces list is replaced by a finite formatter
that emits exactly the demanded alternating characters/spaces. This makes the
strict variant productive without building an infinite list. The source's
finite repeat/take/map/concat workload remains an explicit sequence pipeline;
no symbolic result precomputation replaces the formula transformations. The Haskell
`NOINLINE xs` annotation remains in the raw source; portable SML97 has no matching
per-binding pragma. The port uses ordinary functions for repeat/take/map/concat.
Generated code must be inspected before attributing any specialization or
hoisting to a particular compiler.
Displayed literals retain their trailing spaces, including the space after
`<=` for an empty antecedent. No floating-point or arbitrary-precision work
occurs; all selected repetition, byte and stack-size counters fit 31 bits.

## Inputs, driver and validation

Smoke 1, normal 7 and large 35 preserve FAST/NORM/SLOW. Main's outer 67
repetitions also remain intact. Each copy independently transforms the exact
`(a = a = a) = (a = a = a) = (a = a = a)` literal. The driver reads arguments
and the reviewed one-clause fixture once, instead of obtaining the same command
arguments in every outer iteration. Input checks admit 0..35 copies.

The Haskell original emits each result via putStr. The suite consumes and
compares every output character against the repeated fixture, without first
materializing the result stream as a String. Its final line reports
`67:copies:total-bytes`; expected totals are 402, 2,814 and 14,070. Validation
and the final count add observable work; output streams are controlled by the
suite contract. The selected strings are not replaced by their known byte count.

All three original GHC runs match the pinned stdout bytes. A separate observer
changes only Main's export boundary. It agrees with an independent set-based
CNF converter for 48 formulas, whose resulting clauses are also checked against
complete propositional truth tables. Cases cover every connective, precedence,
association, negation, duplicate/tautological clauses and distribution. Separate
SML checks exercise those complete outputs, wrong results/lengths, deferred
branches/fields/tails, shared elimination and strict materialization. Large SML
execution is claimed only where explicitly recorded in validation evidence.

## Diagnostic questions and references

The [retained program](upstream/Main.hs) supplies the benchmark-specific
algorithm, authorship and correction history. Partain's
[*The nofib Benchmark Suite of Haskell Programs*](https://doi.org/10.1007/978-1-4471-3215-8_17)
provides suite context. Formula expansion, shared AST fields, intermediate
allocation, lexicographic comparisons, lazy short-circuiting, parser stacks and
whole-program specialization are source-based performance hypotheses. Counts
establish only their recorded instrumentation results; no causal timing claim
or historical compiler ranking is transferred. Standard comparisons use
identical SML; Haskell supplies correctness references.
