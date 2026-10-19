# para-lazy provenance

Finite numeric policy: lazy.

### Algorithm and workload

Format paragraphs at maximum width 70 and preferred width 63 using the source
linear-time par3. Retain right-fold scan1, candidate cost/width/length summaries,
symmetric lists as two lists, both rebalance operations, add/breakpoint pruning,
drop_nofit, trim, tile and source parse/unparse. The implementation does not
replace candidate maintenance with dynamic programming or a mutable queue.

### History, authorship and known variants

Oege de Moor and Jeremy Gibbons, 1995--1999; the article header dates its benchmark
program September 1999. Pinned nofib revision
b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/para. This is paragraph
formatting, with no parallel runtime requirement.

The literate source contains its paper, experiments and intermediate algorithms:
exhaustive par0, quadratic par1, cached/pruned par1'/par2 forms, final linear par3
and greedy parg. Original main selects par3. Preserve all definitions as upstream
source; quadratic par1 is an independent original-language reference for a
documented counterexample, not a substituted timed algorithm. No separate
redistribution grant is stated in the Haskell/C++ sources.

The C++ Part2.C comparison has its own bounded buffers, command-line width and
Para/Queue/Thin modules. It remains a distinct future candidate outside the
initial SML/Haskell/OCaml executable set. Retain its source and data; omit the
pinned precompiled i386 part2 executable and record its SHA-256/disposition.
No original executable is imported or executed. The complete article warns
against treating its clarity-first historical comparison as modern performance
evidence.

### Dataset origins and notices

The full input is the supplied Project Gutenberg February 1994 e-text #107,
Far From the Madding Crowd by Thomas Hardy, named crowd10a.txt in its header.
Its individual historical notice includes Charles B. Kramer's Small Print
version 04.29.93, the public-domain statement and distribution terms.
Retain the entire original text/header/notice byte-for-byte in full.input and
upstream/runtime_files/input-data. Preserve the separate CRLF C++ crowd/cout
copies unchanged; do not silently equate their raw identities.

Formatted references retain all original words, including the complete historical
header/notice, with only the benchmark's line wrapping and blank-line formatting.
The original ASCII file is supplied alongside them. Smoke selects complete
novel-body paragraphs after the historical header, with no Gutenberg references;
its exact byte range, source identity and adaptation are recorded. Synthetic
auxiliary cases have deterministic origins. The novel-body counterexample keeps
its original author/source attribution here.

### SML97 translation and evaluation

Lazy and strict names identify memoized versus eager finite numeric summaries
and state/candidate payloads. Both retain memoized list spines, head sharing,
queue shape, scanning order, candidate selection and source right-fold grouping.
The lazy policy can inspect a candidate length without forcing unrelated fields.
No input, formatted output or parsed paragraph is cached across repetitions.

The driver reopens the input each iteration. Portable TextIO.inputAll replaces
hGetContents and produces a memoized character stream; record this eager file
read separately from the source's lazy file IO. Reading fixed ASCII data keeps
word/character classification within the reviewed common domain.
All selected integer widths, costs and lengths fit signed 31-bit int; no
arbitrary-precision or modular-arithmetic substitution is introduced.

The original consumes length of the formatted string and prints nothing. The
driver consumes the same output stream while comparing every character against
the reviewed fixture, then reports repetitions:checked-characters. It buffers
neither an extra full output list nor a parsed-result cache. This validation adds
character comparison to the source length consumer; document it in comparisons.

### Profiles and correctness

| Profile | Repetitions | Text |
|---|---:|---|
| Smoke | 1 | 10005-byte complete body-paragraph selection |
| Normal | 8 | original 789112-byte text |
| Large | 40 | original 789112-byte text |

Normal/large retain source inputs and counts. Smoke keeps FAST's one repetition
and reduces its dataset for bounded routine checks. Original GHC runs finish
all source profiles with empty stdout; there is no supplied para.stdout fixture.
An export-only original formatter produces complete reviewed formatted text:
784213 bytes for the original input and 9969 bytes for smoke.

An independent quadratic dynamic-programming reference verifies preserved word
order, maximum widths and layout costs for all 3574 original paragraphs.
Source costs agree with the optimum on 3573. Paragraph 483, a 23-word quotation,
has source par3 cost 5 versus optimum 1. Original quadratic par1 confirms cost 1.
Preserve par3's three-line layout exactly; this is an established property of
the pinned source, not evidence against the paper's general algorithm.
Partial source behavior on whitespace-only input and overlong words is retained.

The 112-check target compares 41 complete original cases under both policies,
small full text, the source counterexample, output corruption/length rejection,
zero iterations, front/back queue rebalancing and unused-field demand.
Both policies agree with the complete original text in a guarded streaming
pilot. Full normal calibration and canonical primary/count/semantic runs are
recorded separately as they finish. Full large SML repetition checks remain
unrecorded. An earlier development consumer materialized an extra full output
list and exceeded a private 1-GiB guard; retain that development observation
separately from the final streaming consumer's checks.

### Literature and diagnostic questions

[De Moor and Gibbons, Bridging the Algorithm Gap: A Linear-Time Functional
Program for Paragraph Formatting (1999)](https://www.cs.ox.ac.uk/publications/publication2361-abstract.html)
is the source article; the full literate text is preserved. It motivates the
functional derivation and concrete queue representation.
[Partain's nofib paper](https://doi.org/10.1007/978-1-4471-3215-8_17) supplies suite
context. Investigate summary-field demand, symmetric-list sharing/rebalancing,
candidate pruning, paragraph lifetimes, text parsing and output consumption.
These are source-based diagnostic questions; current-host performance claims
need separate measurements.
