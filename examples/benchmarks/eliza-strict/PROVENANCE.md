# eliza-strict provenance

Selected finite candidate/output evaluation: strict; cyclic reply queues remain memoized.

## Algorithm and workload

Run the source's ordered keyword/tail search and cyclic response selection over
its fixed conversation. Trim only space, period, exclamation mark, question mark
and comma from line ends; split into words and discard empty lines. Match the
first key in the original 40-entry order, conjugate its first matching suffix,
rotate only that key's replies, and handle consecutive repeated word lists with
a separate cyclic queue. Preserve trailing-I conjugation, fallback replies,
capitalization, spelling and the two newlines after each response.

Each iteration i starts from the original initial state and selects the first
(i mod 20) input lines. It recomputes the conversation and consumes its complete
character length. The driver checks every length against the reviewed 20-entry
reference cycle and reports iterations:sum:checked. Reference lengths are
checker data, never substituted for computing a conversation.

## History, revision, authorship and aliases

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, spectral/eliza/Main.hs,
Makefile, eliza.stdin and the three stdout fixtures. The header credits the Hugs
version to Mark P. Jones, January 12, 1992, adapted from a Pascal implementation
provided by James Risner with original Pascal code apparently by Robert
Migliaccio. Retain that wording rather than resolving uncertain attribution.
The selected program and 335-byte conversation state no separate redistribution
notice or dataset author; no notice from an unrelated component is substituted.
The exact input is retained, not regenerated or replaced with invented dialogue.

The explicit eliza-lazy/strict names identify evaluation variants of this nofib
implementation. They do not claim to reproduce every historical ELIZA script.

## Lazy and strict variants

Reply queues use explicit shared, memoized cycles in both variants. The initial
state is shared across sessions, as in the Haskell top-level value. A session
constructs a persistent new key table and advances queue pointers without
mutating the initial response positions. Memoized queue nodes may be reused;
computed conversations and their lengths are not cached across iterations.

The lazy variant memoizes candidate-reply and output-character spines, demanding
the first candidate only. Response and next-state fields have separate memoized
delays, avoiding construction of an unused final key table. A fixed response does not force its unused conjugated
suffix. The strict variant constructs finite candidate lists, conjugations and
output characters eagerly. Cyclic queues remain lazy to avoid turning an
infinite producer into a divergent strict initialization. Full output agrees;
allocation, retention and the timing of unused candidate work can differ.

## Portable SML97 translation

Response keys/templates, repeated replies and conjugations are extracted with
an export-only Haskell observer, with all source text retained. SML strings store
words/templates; input lines and word lists are finite strict lists. Loading the
fixed file replaces lazy getContents/lines. Only each selected prefix is trimmed
and tokenized, but loading the small file is strict and happens once per run.
String case conversion and conjugation materialize strings, whereas Haskell
strings are lazy character lists. Output characters and candidate spines retain
explicit delays where evaluation differs between the named variants.

The composed tails/filter/map pipeline is represented by a delayed candidate
list with the same nonempty tails, key order and first-match behavior; intermediate
list layers are fused in this translation. Uppercase mapping within a candidate
uses a finite strict word list. Record these representation and allocation
changes when interpreting measurements; this is not an assertion of identical
Haskell allocation. Reconstructing key tables and rotating cyclic queues preserve
the original persistent state algorithm rather than using mutable keyword counters.

Source numeric parameters and lengths fit signed 31-bit Int. The summary uses
IntInf accumulation explicitly. The initial key-table spine and word preparation use strict finite lists.
Input is ASCII; character behavior outside the
retained workload is not claimed to implement Haskell's full Unicode semantics.
The SML driver checks its positive repetition bound of 65000. It replaces many
printed length lines with checked aggregation; I/O and result checking are
included costs. No external library, runtime extension or compiler hint is needed.

## Profiles and diagnostic questions

Smoke uses 20 iterations to cover one complete prefix cycle. Normal preserves
NORM 13000 and selected large preserves SLOW 65000. FAST 1300 is also checked with
the unmodified original and its fixture. Every run recomputes all selected
sessions, including repeated occurrences of a prefix. No universal size argument
is imposed on conversation data. Default profile time/memory limits apply.

Source-based diagnostic questions concern ordered keyword matching, repeated
case conversion, candidate demand, persistent key-table copying, shared cyclic
queues, character streams and strict finite-result retention. These are
hypotheses until supported by measurements. Standard compiler reports compare
identical SML; original Haskell runs supply correctness evidence.

## References and validation

Unmodified original outputs agree with all three upstream fixtures. An
independent ordered-key/counter model agrees with all 20 complete conversation
prefixes and all 65000 original length rows. Export-only observers supply exact
full response bytes, including punctuation and blank lines. Additional complete
sessions cover repeated inputs, key rotation, trailing I, empty suffix defaults,
fallback and punctuation. SML checks include both variants' full output, cyclic
sharing, demanded/unused suffixes and wrong/truncated/extra output rejection.
Broader host/profile validation is claimed only where recorded in the results.

Joseph Weizenbaum, [ELIZA—A Computer Program for the Study of Natural Language
Communication Between Man and Machine](https://doi.org/10.1145/365153.365168),
Communications of the ACM 9(1), 1966, pp.36–45, provides historical context for
keyword-based conversational programs. It is not a specification for the
particular Hugs response table or evidence of current compiler performance.
The retained nofib source supplies that implementation's exact behavior; the
suite's nofib and measurement survey supplies comparison methodology.
