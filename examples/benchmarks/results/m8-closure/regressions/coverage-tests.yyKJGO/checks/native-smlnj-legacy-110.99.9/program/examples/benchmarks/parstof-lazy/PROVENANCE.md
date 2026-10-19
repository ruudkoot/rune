# parstof-lazy provenance

### Algorithm and workload

Recognize the source's embedded functional-language scheduling program using
a character-dispatch lexer and backtracking parser combinators. Preserve
balanced lexical dispatch by first-character sets, ordered alternatives,
keyword prefixes, token attributes, right-recursive repetition, precedence,
associativity, tuple/union constructors, let/case/if syntax, type declarations
and source error selection/preview behavior.

The original timed consumer observes parser success, not the AST payload.
The lazy variant retains that recognition workload. The strict variant
materializes finite lexical/AST attributes as parsing proceeds; complete
tree comparisons are separate semantic checks rather than extra timed
tree traversals.

### History, authorship, names and notices

[nofib Hartel parstof](https://gitlab.haskell.org/ghc/nofib/-/tree/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/hartel/parstof)
is pinned at b7391df4540ac8b11b35e1b2e2c15819b5171798. The generated module states no separate individual
author or program/data notice. Preserve the complete module, Makefile,
FAST/NORM/SLOW fixtures and parent Fast2haskell shim, without assigning
collection/helper credits to this parser or its embedded program text.

The -lazy/-strict suffixes identify meaningful finite-data demand policies.
This parser is distinct from the scheduling simulator: its input describes
scheduling, while its executed algorithm is lexical/syntactic analysis.
No generated or parsed target program is executed.

### Translation, sharing and semantic decisions

Retain all eighteen typed source AST datatypes, constructor field order and
source combinator grammar. Portable constructor and grammar transcription
scripts are archived with the original source and read-only observers.
Use memoized character/token control for backtracking and shared input.
A cached closure for each of the 42 nonterminals preserves top-level grammar
sharing; explicit source-derived result types make these caches portable
under the value restriction.

Both policies represent semantic attributes with policy-controlled cells.
Conversion/join callbacks remain delayed in the lazy variant, including
unused success attributes. The strict variant forces finite attribute
construction. A character-list attribute materializes its finite SML list
when demanded; default recognition leaves those payloads unused. Control
streams retain per-cell memoization and neither policy eagerly expands
an unbounded parser/control structure.

Preserve left-biased successful alternatives, farther-line known failures
with left-biased ties, and the source repetition/optional combinators'
recovery even from known failure messages. Error formatting remains separately
memoized and takes the first 25 rendered preview characters. Preserve the
missing inequality entry in the source token-display table and the source
hex-escape code-subtraction rule; do not replace them with guessed fixes.

Selected text, decoded character values and names are ASCII/byte characters.
Their identifiers, literals, line numbers, checksums and lengths fit signed
31-bit integers. Haskell Char is wider than SML Char: escapes whose source
arithmetic produces code points above 255 are outside these profiles and
are not claimed to be portable general Unicode parsing. No such escape or
integer overflow is introduced into a selected profile.

Extract the exact positive-index c_the_program literal into program.input
through the original module. Share its memoized character root across all
parses, matching the source constant text. Read CLI/reference files once.
Each iteration constructs the selected number of parser results and traverses
the concatenated success messages with the original sum-plus-length checksum;
lazy numeric accumulators remain delayed. Parser rejection is an immediate
correctness failure.

### Inputs, profiles and result validation

| Profile | Outer iterations | Programs per iteration |
|---|---:|---:|
| Smoke | 1 | 1 |
| Normal | 100 | 8 |
| Large | 100 | 40 |

Normal and large preserve the original Main repetition count and NORM/SLOW
arguments; smoke reduces the source FAST 100 iterations explicitly.
Every recognized program contributes the exact source success message,
26 characters. Each iteration checks its full original checksum string,
2483*n / 26*n with its newline, and returns validated iteration/program/
checksum-byte counts. Suppress repeated stdout and the additional putStrLn
newline, recording that output adaptation.

Read-only GHC observers record complete token streams, ASTs, remaining input
and known errors for ten inputs, including the fixed program, application,
conditional, let/case, lexical escapes, malformed declarations, missing
expressions, empty input and an unterminated comment. Both policies must match
all complete observations. The original FAST/NORM/SLOW executions also match
their supplied fixtures.

An independent ordered regular-expression lexer agrees on all 1898 observed
tokens. A separate structural check validates AST constructor ownership,
arity, primitive types and selected integer bounds. This is not a second
full parser or a general parsing-equivalence proof.

Direct controls test unused/shared semantic callbacks, strict demand,
alternative/sequence short circuits, known-error priority and recovery,
deferred/shared error text, cached grammar use, zero work and rejection of
incorrect programs/checksums. Read-only JSON renderers support these checks;
the benchmark driver does not call them.

Common explicit character and cached-nonterminal types resolve the initial
portable typing errors. Earlier incomplete attempts are retained; the final
20 semantic groups and all 56 profile cases pass on every selected host and
Rune engine, without changing expected answers.

### Compiler/runtime questions and evidence limits

Investigate backtracking, shared token tails, grammar closures, unused AST
allocation, finite-field materialization, higher-order combinators and checksum
accumulators. These are source-based hypotheses. Closed-input specialization,
constant sharing and allocation are not assumed identical between Haskell
and SML compilers, and no opaque evaluation barrier is claimed.

### Literature and review scope

The previously reviewed Hartel and Langendoen (1993) translation account
supplies collection context. Specific lexer/parser algorithms, grammar,
recovery rules and demand behavior come from pinned source inspection and
original observations. No separate parser-construction paper is claimed as
the derivation of this generated module. Correctness observations do not
establish a compiler performance explanation.
