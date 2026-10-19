# nofib parser provenance

## Algorithm and workload

Tokenize Haskell source, apply layout, and parse modules with higher-order
combinators and a fixity environment. Build the source AST, preserve the next
token and environment, render the complete report, and compute the source's
strict left-fold hash. Preserve 500 fresh parses and reports per invocation.

## History, authorship, revision and aliases

Use nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/parser, Main.hs.
The selected source and input headings do not state an author or a separate
licence. Retain the actual original headings and this gap. The three input
files contain progressively larger portions of the Parser module; they are
upstream fixtures. Their source identities are recorded independently.
The canonical common/NofibUtils.hs and its directory symlink are recorded
separately. The utility uses a strict fold and an explicit salt barrier.

## Known variants

parser-lazy memoizes finite token attributes, AST fields and output lists.
parser-strict evaluates those finite attributes eagerly. Both keep memoized
lexer/parser control, positions, alternatives and the infinite EOF stream.
Their complete outputs agree with GHC for every selected profile. The name
has no classic SML collision; these policies are explicit suffixes.

## Translation and adaptations

Retain the combinator algorithms, alternative order, first-success behavior,
furthest-error comparison and dynamic precedence/associativity handling.
Recursive parser builders are memoized functions, without caching parse
results. Preserve the source's parenthesized-token text quirks, nonnested
comments, backquoted identifiers, column accounting and CPP-line skipping.
An EOF singleton cycles with line/column 99997. Position delays preserve the
source's ignored undefined line number after a lone hash at EOF.

Retain ShowS-style character output and Haskell literal Read/Show behavior.
Selected input is ASCII. The input string is read eagerly before memoized
character consumption, and remains shared across repetitions. Each repetition
constructs fresh lexer/parser/report work. The Haskell salt barrier maps to
this explicit driver call boundary; no new compiler feature is introduced.

Selected integer literals and positions fit signed 31-bit integers. Hashes
use explicit modular 64-bit arithmetic, with signed rendering through IntInf.
This preserves the pinned 64-bit GHC hash on hosts with narrower default Int.
The driver checks every complete-report hash, prints each source hash line,
then reports the verified repetition count.

## Inputs, validation and limits

Smoke/normal/large preserve parser.faststdin, parser.stdin and parser.slowstdin:
992, 6949 and 43999 bytes, with 500 repetitions each. Original complete reports
have 1434, 15653 and 98649 bytes; retained reference files expose every byte.
Their signed hashes are 4438664785162099485, -175746672012950975 and
-9015528911864443912. Each profile records its full modular digest in the manifest.
Default time/memory limits apply unless a later recorded override says otherwise.

Private checks agree with upstream stdout fixtures and all six complete
Need/Strict reports. Additional observations cover complete raw/layout token
streams, 26 lexical controls, 33 typed parser cases, all report hashes, ignored
input/continuations, error-position demand and semantic sharing. The original
500-repetition smoke and normal drivers pass locally. Public profile, count and repository acceptance checks are recorded below.

## Runtime questions and literature

Higher-order calls, closure lifetimes, recursive parser construction, failed
alternatives, layout, AST allocation and report generation are source-based
diagnostic questions. Attribute materialization and retained input can affect
space use. Performance conclusions require measurements of the identical SML
sources on each host.

[Hutton and Meijer, Monadic parser combinators (1996)](https://nottingham-repository.worktribe.com/output/1024440/monadic-parser-combinators)
is background on higher-order parsing. No authorship or direct derivation of
this historical parser is inferred from that report. Original Main.hs and
the retained fixtures remain the implementation references.

### Compilation and execution phases

SML/NJ exported images evaluate declarations while the image is built.
Global tables and memoized streams can therefore enter the compilation
phase. Record build and fresh-process execution separately and interpret
them together. Repeated execution retains source global sharing and does
not imply steady state. Profiling/count instrumentation runs separately.


### Recorded public validation

The [application-wave evidence](../results/m4-parser-reptile-hpg-fluid/README.md)
records smoke/normal checks at O0/O2, all applicable Rune engines, supplied SML
hosts, independent semantic assertions, normal allocation counts, serial
adapter diagnostics and full repository acceptance. All 128 Rune profile
combinations pass. Host failures remain explicit; this link does not imply
that every host or the full large matrix passed.
