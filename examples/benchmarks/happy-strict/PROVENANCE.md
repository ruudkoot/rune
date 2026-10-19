# happy-strict provenance

## Algorithm and workload

Parse an annotated context-free grammar with the generated Happy bootstrap
parser, mangle names and semantic actions, compute FIRST and LR(0) closures,
construct numbered states, propagate LALR lookahead sets, resolve conflicts,
and generate Haskell parser source. Retain source-order searches, stable
natural mergesort, size-balanced sets and boxed immutable array cells.
The benchmark generates a parser; it does not execute that generated parser.

## History, authorship, upstream revision and aliases

Import nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, gc/happy.
Happy 1.16 is by Andy Gill and Simon Marlow; individual module headings
retain dates and additional credits. GenUtils declares its code public
domain. The complete historical release LICENSE has two redistribution
conditions and credits the Durham GLR extensions to Paul Callaghan and
Ben Medlock. Preserve its actual wording instead of substituting current
package-registry metadata. The separately retrieved happy-1.16 release
has SHA-256 4da47f4904dbdddfb58140edb0395383feba72dfc77759e57587a526dd9496c5;
its identity and per-module comparisons with nofib are retained.

TestInput.y is the GHC grammar with its own University of Glasgow
1997–2003 copyright and Simon Marlow/Sven Panne 1997–1999 authorship.
Retain that notice independently of the program licence. Embedded
Haskell declarations, imports and foreign declarations are uninterpreted
input text. They are not dependencies of the SML benchmark.
The nofib tree does not contain a separate Happy LICENSE file; the
matching release's full notice is retained with its distinct provenance.

The used Data.Set implementation is containers 0.6.7 at
9f4a93604c66a5e605ce46fc30003b71802b3cfd. Retain its original source and
CONTAINERS-LICENSE, including Daan Leijen's attribution.
Used Read/Show literal operations follow GHC 9.4.7, base 4.17.2.0,
ghc-9.4.7-release (commit 00920f176b0235d5bb52a8e054d89a664f8938fe). Retain GHC/Show.hs, Text/Read/Lex.hs and the full base
LICENSE with source identities. This is translation support, not an FFI.

## Known variants and selected build

Happy offers multiple backends. The pinned nofib Makefile supplies only
TestInput.y, selecting TargetHaskell with coercions, GHC extensions and
strict generated-parser mode disabled. Main explicitly replaces template
loading with an empty template. Preserve that actual benchmark configuration.
The source excludes generated TestInput.hs from compilation. Its optional
array/coercion/GLR/debug/info backends are retained as original source and
are outside this selected executable workload; no passing port of those
unselected tool modes is claimed. No missing runtime feature is invented
to justify that build scope.

Use happy-lazy for memoized finite data and happy-strict for eager finite
data. Both retain memoized parser/state/control roots to tie finite
recursive dependencies. The latter is a separately named evaluation and
allocation experiment. The grammar, algorithms, state numbering and full
generated output agree. No classic-name collision requires a source suffix.

## Translation and adaptations

Keep direct higher-order generated parser actions and typed reduction
functions; do not replace the bootstrap parser by an interpreter or another
parsing algorithm. Preserve lexer and parser lookahead/line handling,
HappyDontSeq semantics, error recovery and undefined stack bottoms.
Attribute grammars retain their own generated parser and formatting rules.
Quoted Haskell literals follow Read/Show, including numeric escapes,
string gaps, maximum munch and escaped-dollar handling. Selected source
input is ASCII; Unicode escaped values use integers through 1114111.
No claim is made for decoding arbitrary raw UTF-8 input as Haskell Char.

Explicit memoized delays preserve sharing and ignored arguments, including
FIRST suffixes and closure fixed-point tests. Preserve the inclusive extra
start rule in LR(0), repeated initial spontaneous entries, inclusive extra
lookahead row, propagation snapshot ordering, priority equality that
ignores associativity, and the source's redundant reduce/reduce guard.
These are source behaviors rather than textbook repairs.
Sets retain delta 3, ratio 2, strict tree spines, ascending-run construction
and used union/difference/filter operations. Portable SML has no immutable
pointer-equality primitive: unchanged-size checks replace applicable
pointer shortcuts, and equal-key insertion always replaces the key.
This preserves reviewed shape and bias but changes support allocation.
Do not interpret the two runtimes' object layouts as identical.

Boxed vector-backed immutable arrays retain memoized element roots and
undefined cells. Mutable propagation storage copies captured row pointers
before publishing immutable results. Lazy output uses character lists and
ShowS-style composition; strict finite-data materialization can allocate
the complete finite output earlier. The generated TestInput.hs is written
in the fresh working directory, then read and compared completely.
Warnings retain source order and bytes, are checked, and reach stderr.
File contents are read eagerly into SML strings before lazy tokenization;
this is an explicit input-retention difference from Haskell lazy readFile.
All selected integer names, sizes and counters fit signed 31-bit integers.
The reference-number reader checks its explicit 31-bit domain with the exact
quotient/remainder bounds for decimal, hexadecimal and octal. This avoids a
reproduced SML/NJ 110.99.9 32-bit false Overflow in the valid dynamic expression
(1073741823 - 1) div 10. The constant-folded expression succeeds on that host.
The original helper and failing observations remain preliminary evidence.
This translation-support workaround does not change selected semantic actions,
integer width, source algorithm or expected results; boundary acceptance and
rejection are checked explicitly.

Thin drivers select files and report consumed byte counts. They add result
validation to the original unchecked writeFile. Full original source,
individual notices, release/source identities and all adaptation sources
remain available. No prerequisite compiler or runtime feature is added.

## Profiles and validation

Smoke uses a small deterministic expression grammar with precedence,
created for the port. Normal uses the unchanged complete upstream
TestInput.y once, with the original empty-template code-generation mode.
The upstream Makefile supplies no distinct FAST/SLOW grammar: no artificial
large profile is registered. Future scaling inputs require explicit
selection and independent original-language results.

Smoke explicitly overrides the default to 120 seconds/4 GiB; normal
retains 600 seconds/4 GiB. The existing matrix applies profile limits to
compilation as well as execution. The preliminary default 30-second smoke
compile timed out on SML/NJ development, and the 1-GiB ML Kit compile failed
with an empty log whose cause is unclassified. The override supplies room
for compiling the complete generator; it does not establish the cause of
that ML Kit failure. The small grammar and expected output are unchanged.

Every generated byte and warning byte must match the reviewed GHC output;
counts alone are insufficient. The normal parser has 706113 bytes and
SHA-256 b70da0bb178d71e52aa624e57ae8d0955ab7f905941187c96285e0874639e793,
with 33 shift/reduce and one reduce/reduce conflicts. Private source
observers compare lexer streams, full bootstrap/attribute ASTs, complete
mangled grammars, set shapes, FIRST, LR(0), lookahead stages, action/goto
tables and full code-generation output. End-to-end comparisons include
warnings. An exceptional out-of-domain reference uses exception category,
not the GHC-specific source-location text. Host/configuration validation
and final acceptance are recorded separately; registration alone is not
completion evidence.

## Performance questions and references

Source inspection suggests recursive calls, higher-order parser actions,
memoized demand, persistent-set operations, closure fixed points,
shared immutable arrays, propagation and character allocation may affect
performance. These are diagnostic hypotheses until separately measured.
Generating Haskell imports and FFI declarations does not benchmark FFI
execution. Compilation of the generated parser is also outside this workload.

The [Happy manual](https://haskell-happy.readthedocs.io/en/latest/introduction.html)
describes annotated-grammar input and generated-parser modes; its
[tips](https://haskell-happy.readthedocs.io/en/latest/tips.html) discuss
conflicts and grammar-dependent parser behavior. The present-day manual
provides background; pinned source establishes the historical configuration.
[DeRemer and Pennello, 1982](https://3e8.org/pub/scheme/doc/parsing/Efficient%20Computation%20of%20LALR%281%29%20Look-Ahead%20Sets.pdf)
provides background on LALR lookahead computation and incorrect alternatives.
It is not evidence that this Happy source implements that paper's SCC algorithm.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17)
motivates application coverage. Separate source explanations, literature
background and recorded observations from timing conclusions.


### Recorded validation outcome

[Full evidence](../../../../rune-benchmark-results/m3-happy/README.md) records 78 of 80 tagged
profile passes, all 40 normal runs and 50280 semantic assertions.
Two lazy smoke ML Kit compiles fail with empty logs and unclassified causes;
normal and complete semantics pass on that host. Eight normal count samples
agree. Six final serial native adapter samples and their preflights pass.
Repository acceptance exits zero, including all 498 compiler and seven-host
runedoc/runeopt comparisons. Native level labels use host-default flags.
These outcomes complete this import wave without closing M3, M4 or M8.
