# symalg-lazy provenance

### Algorithm and workload

Run the source symbolic arithmetic command interpreter: lexical analysis,
precedence parsing, persistent environment lookup/update, expression
evaluation and printing. Its supplied workload sets decimal precision and
repeatedly computes square roots of integers two through ten. Preserve the
RealM arbitrary-precision decimal approximation algorithms and memoized
infinite trees, rather than replacing them with floating square roots.

### History, source variants and notices

[nofib real/symalg](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/real/symalg)
is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. The individual modules state no author, dated
program history or separate license grant. Preserve all twelve original
modules, NofibUtils, Makefile and FAST/NORM/SLOW fixtures; do not infer
authorship from collection maintainers or incidental comments.

The -lazy/-strict names distinguish delayed finite AST/numeric values and
approximation-tree integer labels. Infinite tree branches remain memoized
in both. BasicNumber and BasicNumberApprox contain inactive class helpers;
the runnable command interface retains all reachable lexer, parser,
environment, evaluator and printer behavior. No external dataset is needed.

### Translation and numeric semantics

Use IntInf for source Integer values, rational numerators/denominators,
approximation-tree labels and precision arithmetic. Preserve truncating quot,
the source rounding biases and intermediate decimal scales. Tree lookup
follows the original binary path for 1-tolerance; mapping retains shared
numberTree structure and per-approximation memoization.

The source square-root iteration uses a binary64 seed only at its original
base case. Preserve that conversion, nearest/even rounding and subsequent
integer refinement. Decimal tokens containing nonzero fractional digits
follow the original default binary64 read then exact rational conversion;
do not silently substitute the decimal rational. Replace Data.Ratio with
normalized IntInf pairs and explicit gcd/cross-product arithmetic, recording
this library implementation/allocation difference.

Retain the source operator precedence, associativity, symbolic unknown
functions, literal/evaluated assignments, environment order and print quirks.
Negative rational numerators keep the source extra parentheses. Source
RealM comparisons use its precision-dependent two-unit band where invoked.
Positive sqrt profiles require exact original decimal strings; no floating
tolerance is substituted for their arbitrary-precision results.

AST nodes, evaluated number payloads and integer labels follow the finite-data
policy. Token descriptors and finite argument/environment list spines are
strict portable metadata containing delayed values. Infinite approximation
branches always use explicit memoized delays. Only selected ASCII command
inputs are supplied; Data.Char is replaced by portable SML character predicates.
No Unicode runtime or other prerequisite feature is added.

The source output hash has tested signed 64-bit machine semantics, made explicit
with Word64 modular arithmetic and IntInf signed conversion. The same sources
run on every host, including hosts with default signed 31-bit integers.
Selected precision/exponent metadata fits that range.

### Inputs and complete result validation

| Profile | Decimal precision | sqrt commands | Parameter source |
|---|---:|---:|---|
| Smoke | 20 | 9 | Small complete source command cycle. |
| Normal | 300 | 9 | Reduced precision and one source command cycle. |
| Large | 3000 | 9 | Original FAST precision, one source command cycle. |

Each cycle evaluates two through ten and exits deterministically. Originals
use 261 sqrt commands at precisions 3000/15000/40000 for FAST/NORM/SLOW.
Preserve all original scripts/results and document these reductions.
Longer precision pilots retain their actual guard/timeout outcomes separately;
selected normal validation does not claim completion of the original scripts
or the full SML large profile.

Preload fixed script/reference files in SML97; stream prompts and command
outputs to an online exact checker. Additionally observe every complete
formatted numeric string before hashing and compare it with reviewed full
original values. This adds a uniform validation callback/traversal, potentially
affecting optimization; it is not an assumed opaque barrier or an identical
I/O cost. Reset the callback on success and failure. Suppress terminal output
and return checked numeric-value and transcript-byte counts.

An output-only Haskell observer replaces hashing with full numeric text;
unmodified originals separately match all supplied hashed fixtures. Complete
original sqrt values through 40000 digits also agree with an independent
integer-square-root oracle. Compare each scaled value with the exact floor;
the measured gap is recorded, with a one-decimal-unit permitted bound.
Runtime references remain exact source strings.

Additional original command transcripts exercise help, empty commands,
assignments, environments, arithmetic/precedence, rational/real conversion,
unknown functions, comparisons and syntax errors. Direct arithmetic observers,
memoized-tree sharing, zero-product demand and deliberately perturbed complete
numbers/transcripts provide independent checks. The original zero-times-
nonzero exact-real magnitude search can fail to terminate; do not repair
inactive/source-bug paths silently or include them in successful fixtures.

### Compiler/runtime concerns and evidence

Investigate arbitrary-precision representation, integer multiplication and
division, memoized precision reuse, infinite-tree retention, closure
specialization and AST forcing. Library rational replacements, strict finite
spines and extra validation are explicit costs. These are hypotheses from
source inspection; passing values or count agreement does not assign
individual performance causes.

Recorded semantic, smoke/normal profile, count and repository acceptance
outcomes are separate in the validation ledger. Native group labels use
host-default flags; Rune compilation levels are checked explicitly. Full
original SML FAST/NORM/SLOW and selected large runs remain separate checks,
never inferred from small-input or original-Haskell results.

### Literature and review scope

[Partain's nofib suite paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies application-coverage context at the
survey scope already recorded. RealM.hs supplies the particular decimal-tree
representation, scale rules, magnitude search and Newton-style recurrences.
No external exact-real paper is claimed as the derivation of this source.
Original observations and integer square roots support numerical validation;
compiler/collector and arithmetic-cost questions require separate measurement.
