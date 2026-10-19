# boyer-nofib-lazy provenance

Selected finite term/argument evaluation: lazy; recursive lemma streams remain memoized.

## Algorithm and workload

Apply the source substitution to its transitivity theorem, recursively rewrite
terms with attached function lemmas, and check the resulting conditional form.
Terms are typed Var IDs or Fun IDs/arguments/lemmas; equality deliberately ignores
lemma fields. Preserve one-way unification, variable binding order, rewrite
priority, conditional assumptions and short circuiting. The source Main performs
100 repetitions; each test checks n instances from an opaque repeated Var X list.

## History, revision, authorship and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/boyer/Main.lhs,
Makefile and three stdout fixtures. The header names Bob Boyer, Bob Shaw and
Will Clinger, and credits Denis Howe's July1992 Scheme-to-Haskell conversion.
Its Status explicitly says Public Domain; retain the complete notice/history.
The included Scheme listing is comparison material, not a second executable.
The source notes that some unused Scheme lemmas were not translated.

Classic SML boyer keeps the unsuffixed name. These variants use
boyer-nofib-lazy/strict. The other nofib boyer2 uses textual Lisp parsing and an
unbalanced LUT, with different rule data/input quirks. Do not merge its binary
Lisp implementation with this typed-ID/per-Fun-lemma representation merely
because both ultimately prove the transitivity statement.

## Lazy graph, strict variant and exact behavior

The lazy variant memoizes term/argument heads and spines. Each function's
invariant lemmas are represented by one shared memoized rule stream; terms
retain the attached stream pointer. This explicit rule graph remains lazy in
both variants because constant/function lemmas refer recursively to their own
function nodes. Strict term/argument construction does not force those cyclic
rule fields. Unused rules are not normalized eagerly (for example, the unused
unconditional gcd swap is not a new terminating API).

Failed unification/find results keep their delayed error field. Matching tests
the Boolean before demanding the environment. Argument matching requires both
lists to end, unlike boyer2's source prefix rule. Substitution copies the original
lemma pointer; term equality traverses IDs/arguments without touching it.
The strict variant eagerly constructs finite term/argument structure while
retaining the necessary memoized graph and failed-result control. Results agree.

## Portable translation and input generation

SML97 uses closed enum codes for all50 IDs (nine variables, 41 functions),
retaining exact names/mapping and constant-time ID equality. Generated constructor
functions preserve the original finite ASTs; argument factories defer child
construction in the lazy variant. No runtime text parser or different symbolic
term encoding is inserted into the kernel. Rule/theorem/substitution data are
extracted with export-only Haskell observers; original source and generation
scripts are retained. The extraction adds Show/exports and exposes the original
where bindings without changing numeric/rewriting expressions.

The runtime variable file replaces source NOINLINE xs with an opaque portable
input dependency. It starts with a repetition count, followed by one variable-
name row per test. The selected rows contain exactly the source's repeated X;
the parser permits every original variable ID so it does not reveal a constant
X to the optimizer before computing. SML97 generation writes these fixed rows.
Input I/O/name parsing is an explicit added driver cost. A valid result checks
every theorem before reporting repetitions:proofs:proved instead of 100 True
lines. Bounds are 1..100 repetitions and at most75 variables per row. Counter/
ID/list sizes fit 31-bit Int; no machine-width arithmetic is silently changed.

## Profiles, checks and diagnostic questions

Smoke preserves FAST2 per test, normal NORM15, and selected large SLOW75; all
preserve 100 source repetitions. Immutable rule/input constants may be shared,
while every theorem construction/substitution/rewrite is invoked through its
runtime variable. No previous theorem result is cached as a repeated-run answer.
No dataset or external runtime feature is required.

Original complete outputs match all three fixtures. Original and independent
models agree on the full instantiated input and 170284-byte normalized form for
X. All nine variable inputs are checked independently over all32 truth
assignments: only X is a tautology. Complete SML lazy/strict forms agree byte
for byte. These supplemental observations force full results only in tests,
not in the timed Boolean consumer. Tests cover graph-safe equality, unification
bottoms/short circuiting, exact argument lengths and wrong/truncated/extra forms.

Source-based questions include enum dispatch, attached-rule sharing, recursive
argument demand, failed matches, eager unused terms, input setup and invariant
specialization. They remain hypotheses until supported by inspection or
measurements. Standard reports compare identical SML; Haskell is a correctness
reference. Large execution is claimed only where recorded.

## Literature and source explanations

The retained literate program explains why its theorem/substitution are chosen,
how typed terms differ from the Scheme property-list representation, and which
setup work belongs to that original comparison. Gabriel's Performance and
Evaluation of Lisp Systems supplies the benchmark's historical context, and
the nofib/measurement survey frames current comparisons. Historical remarks
about language advantages or costs do not establish current SML rankings.
