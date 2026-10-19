# boyer2-strict provenance

Selected evaluation: strict finite terms, LUT paths and rule-bucket spines.

## Algorithm and workload

Parse a Lisp-like rule base, construct its unbalanced lookup tree, substitute
into a transitivity statement, rewrite arguments before ordered lemma attempts,
and check the resulting conditional term as a tautology. Each iteration inserts
a distinct cN atom into two substitution terms. Preserve statement/substitution
text, rule insertion order, association lookup, short circuiting and every result.
The z substitution uses the source's [] symbol, without renaming it to nil.

## History, authorship, revision and variants

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/boyer2/Main.hs,
Lisplikefns.hs, Rewritefns.hs, Checker.hs, Rulebasetext.hs and Makefile. Headers
credit Tony Kitto's Hope+ work beginning March1988 and record a June1993 Haskell
conversion as JSM; do not expand those initials without evidence. Rule comments
cite Gabriel pages118..126 and record the altered or rule. Individual files
state no separate license; retain their notices without importing the public-
domain claim from the different nofib boyer program.

Classic SML boyer and nofib boyer share ancestry, but this implementation parses
text into binary Nil/Atom/Cons nodes and uses an unbalanced string-keyed LUT,
rather than per-function embedded lemma fields/property lists. It also varies
cN each iteration. Preserve these material variants as boyer2-lazy/strict,
without conflating their implementations or expected normal forms.

## Exact source behavior and quirks

The lexer treats only space and parentheses as delimiters. Tabs remain symbol
characters. Trailing spaces can produce an empty token; top-level leftover
tokens return Nil. The parser accepts end-of-input without a final close.
Selectors on non-cons values return Nil. Association lookup stops on malformed
entries. Unification terminates successfully when the first argument list ends,
even if the pattern list has remaining arguments. Do not silently strengthen
it to equal-length matching.

One retained difference rule has no RHS after parsing. The source accepts it
into the LUT and caddr returns Nil. Preserve that exact malformed string and
behavior; independent references explicitly account for it. New rules prepend
to a matching bucket, so reversing insertion priority changes the workload.

## Portable translation, laziness and state

SML97 retains binary Lisp nodes, association lists, unbalanced persistent LUT
nodes and ordered rule buckets. The lazy variant memoizes term/tree/bucket
spines and fields; substitution and rewrite results are demanded by the checker.
The strict variant constructs finite terms, bucket spines and LUT paths eagerly.
Both retain short-circuit matching/Boolean logic and agree on results. A shared
Nil and empty bucket represent source nullary constructors.

Tokens use immutable SML strings instead of Haskell character lists; tokenization
is strict while preserving exact token boundaries and text. Literal rule strings
are extracted byte-for-byte, including spaces, into a portable SML data module.
The original raw source and extraction/reference scripts remain available.
The active rule base and statement are immutable CAF-like caches. An outer
memoized delay in both variants keeps parsing/LUT construction inside runtime
execution, including native-host export adapters. Repeated in-process calls may
reuse these immutable caches, as the source does; fresh-process runs start anew.
No mutable substitution state leaks between theorem inputs.

Indices/counts use bounded default Int; selected 0..3000 inputs and rule/string
sizes fit 31 bits. Runtime cN construction uses decimal positive integers. No
arbitrary-precision or modular numeric operation is silently substituted.

## Inputs, validation and compiler/runtime questions

Smoke runs one theorem; normal preserves NORM600 and large SLOW3000. Upstream
FAST60 also has a complete reference. Every original result/report line agrees
with the pinned fixtures. The portable driver validates every Boolean result,
then reports count:proved instead of printing the repeated report sentence.
Bounds and output suppression are explicit driver adaptations. No dataset or
external runtime facility is needed.

Four complete input/rewritten forms agree between original GHC and an independent
proper-tree/dictionary rewrite model. An independent truth-table evaluator checks
all 32 assignments for each normalized formula. SML lazy/strict variants compare
every byte of the complete normal forms in supplemental checks. Negative checks
reject wrong, truncated and extra forms; small tests cover parsing, rule order,
unification quirks, failed-head tail demand, substitution and false formulas.
Forcing complete normal forms is a test observation, not extra benchmark work:
the timed driver retains the original tautology check's demand pattern.

Source-based questions include parsing cost, string comparisons, unbalanced LUT
shape, rule priority, memoized rewriting, eager unused terms, sharing and cache
warmup. Treat them as hypotheses until measured/inspected. Standard comparisons
use identical SML; GHC supplies correctness references. Large execution is claimed
only where recorded. Gabriel's Performance and Evaluation of Lisp Systems and
the nofib/measurement survey supply context; their historical results do not
establish causes or rankings for this translation.
