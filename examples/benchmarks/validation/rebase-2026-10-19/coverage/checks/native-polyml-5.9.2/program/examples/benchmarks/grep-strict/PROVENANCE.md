# grep-strict provenance

## Algorithm and workload

Parse a regular expression with ordered list-of-successes combinators, produce
a cyclic nondeterministic automaton, compress epsilon transitions into tables,
then interpret that graph on each input line. Keep transition order, duplicate
states, separate character/any/end transitions, and the source's final-state
rules. Do not substitute a host regex library, DFA, or deduplicated state set.
The selected expression is `.*:..*`, matching complete lines with a colon and
at least one following character. All matched lines are concatenated with LF
before nofib's polynomial hash, once per repetition.

## History, revision and notices

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `real/grep/Main.lhs`,
`Parsers.hs`, `Makefile` and `common/NofibUtils.hs`. The parser revision log
names thiemann in 1993/1994 and Partain's 1996 import. The unused StringMatch
module explicitly names Peter Thiemann; Main does not establish an individual
author. Retain that module as provenance, while following Main's NFA algorithm.
No individual program or dataset redistribution grant is supplied in these
pinned files; keep that provenance gap explicit.

The input files retain Wikipedia XML, revision timestamps, contributor metadata
and article text. Their shared byte prefix matches the existing compress input,
whose Makefile identifies enwik8. [Mahoney's corpus description](https://mattmahoney.net/dc/textdata.html)
identifies enwik8's parent as the March 2006 English Wikipedia dump. This supports
the parent-corpus association, without establishing an additional grant in the
copied subsets. Preserve the exact pinned input files and identities, rather
than rebuilding them from a newer dump. Selected-line fixtures derive from
those same files and retain their relationship to the full input provenance.

## Variants and translation

The memoized variant preserves parser-result, transition-table and active-state
sequence demand with explicit cached delays. The strict variant eagerly builds
those finite sequences. Both keep memoized graph edges for recursive star/plus
knots; eagerly unfolding a cyclic graph would not terminate. Thus `-strict`
describes the finite sequence evaluation policy, not removal of graph sharing.
Both variants use the same producer, compression and interpreter functors.

Portable references tie the same graph knots. Node headers and exceptions are
memoized, and the final constructor has a shared delay. The source precondition
excludes epsilon cycles; recursive forcing of such an invalid graph fails the
delay guard instead of looping. No valid selected expression has that cycle.
Parsing preserves its unusual syntax: escaped groups/alternation, literal ^,
$ as a literal when followed by another character, and first-parse selection
without requiring all regex input to be consumed. These are not POSIX rules.

UTF-8 acquisition uses portable SML97 and Unicode scalar integers, so non-ASCII
input is not silently treated as bytes. The decoder rejects invalid encodings,
overlong sequences, surrogates and values beyond U+10FFFF. Full file decoding,
strict line buffers and BinIO replace Haskell's lazy UTF-8 handle/getContents.
Input code points are shared across repetitions; line splitting, regex parsing,
NFA production and matching remain within each iteration. Strict acquisition
and line-buffer copying change input representation, demand and allocation.
They are measured adaptations, not a claim of identical Haskell IO costs.

Source hashing preserves signed 64-bit GHC Int wrapping with Word64 arithmetic
on code points, including each LF. The repetition total is explicit IntInf.
Parser token values, indices and lengths fit 31 bits for selected inputs.
A leading SML ~ replaces Haskell's - when formatting negative reported totals.

## Inputs and validation

Smoke uses original FAST data and one repetition; normal retains NORM data and
150 repetitions; large retains SLOW data and 250 repetitions. Original FAST's
100 repetitions and all upstream hash fixtures remain recorded as references.
Every iteration checks the complete ordered matched-line sequence against a
reviewed UTF-8 fixture before hashing, then consumes its hash in the total.
That full comparison and fixture loading are additions to the original hash-only
observation and contribute to measurements.

Unchanged GHC agrees with independent Unicode-aware fixed-pattern filtering and
all pinned hash fixtures. A separate GHC observer confirms every selected line
byte for byte for each profile. Semantic checks cover parser ordering and quirks,
quantifiers, cyclic graphs, deferred successors, memoization, UTF-8 scalar
boundaries, malformed input and line splitting. Large SML execution is claimed
only for recorded runs. Failed host/configuration cases remain separate from
passing ports and cannot contribute measurements.

## Runtime questions and references

Parser specialization, graph sharing, epsilon-table traversal, duplicate active
states, UTF-8 representation and delayed versus eager sequence allocation are
source-based diagnostic hypotheses until measured or established by IR analysis.
The source has no explicit DFA conversion or state-set deduplication.

For related parser-combinator background see Hutton and Meijer,
[*Monadic Parsing in Haskell*](https://nottingham-repository.worktribe.com/output/1024100),
JFP 8(4), 1998. That later tutorial is not claimed as the ancestry of Thiemann's
earlier source. See also the retained implementation, Partain's nofib suite
paper, and the shared demand and measurement survey.
