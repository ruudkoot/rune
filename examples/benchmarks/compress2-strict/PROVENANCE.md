# compress2-strict provenance

nofib b7391df4540ac8b11b35e1b2e2c15819b5171798, real/compress2,
Main.hs, Encode.hs, WriteRoutines.hs, NofibUtils.hs and Makefile. Individual
program authorship and a redistribution notice are unstated in these files.
Retain them unchanged with source identities. The adjacent experimental C
programs are upstream reference material, not executed by this Haskell driver.
No authorship is inferred from the separately implemented real/compress.

## Algorithm and known variants

Preserve the persistent five-field prefix trie, balanced initial alphabet,
first entry 257, variable 9..16-bit events, dictionary-full ratio checkpoints,
clear/reset behavior and the exact writer. The fixed 12-bit compress program
has a different trie representation, dictionary limit, packing and EOF rules.
It remains separately named. No mutable hash dictionary or general .Z codec
replaces this implementation; format quirks are checked against upstream.

The encoder and writer form a feedback knot: the writer supplies byte-count
sizes required by the encoder's strict six-field state. Code events and paired
byte/size streams use explicit memoized delays and share their projections.
A knot reference is installed before demand and cleared after its initial size
view is acquired. Writer sizes do not force code payloads unnecessarily.
The strict variant eagerly constructs/updates the finite dictionary. Essential
causal event/feedback streams remain memoized in both variants; making the entire
cycle eager would prevent evaluation. Strictness scope is explicit rather than
claiming a wholly eager translation of a cyclic lazy program.

## Portable representation and numeric decisions

Input tails become indices into the same binary string. Updated match/trie
results are shared. EOF can discard an updated subtree without demanding its
previous dictionary. Word operations replace GHC unboxed bit primitives with
identical selected nonnegative values below 24 bits. State counters/ratios for
selected inputs fit signed 31 bits. Hashes preserve GHC 64-bit Int wrap via the
existing Word64 nofib hash helper; the suite's final sum uses IntInf.

The consumer forces a complete compressed string, compares every byte to a
reviewed fixture, then hashes it. This adds a final representation/copy versus
upstream's lazy string fold and is part of measured execution. Dictionary and
feedback evaluation retain their explicit demand/sharing distinctions. The
source header 1f9d90, partial-width behavior, padding and final extra byte rules
are preserved without assuming compatibility with a different .Z implementation.

## Inputs, notices and result checks

The Makefile identifies enwik8 as its input origin. The retained XML fragments
contain their Wikipedia site/page/revision/contributor attribution. No separate
input redistribution notice is supplied in the pinned files; that provenance
gap remains explicit, as with the existing compress import. The data source
[describes the March 2006 Wikipedia dump](https://mattmahoney.net/dc/textdata.html).
The suite preserves exact 1944/10755/39864-byte upstream input profiles, not a
synthetic distribution. No license grant is inferred from the download URL.

Smoke uses one iteration, normal and large preserve the source 500 iterations.
Each iteration trims i mod 31 bytes from the input, preserving the source ordering.
The common compression driver validates the complete result against one of 31
original-GHC byte fixtures before accepting its signed 64-bit hash. The final
unbounded aggregate is reviewed independently against all 500 pinned output
hashes. Source stdout prints each hash; the suite reports their checked sum.

GHC observers change only the export boundary and binary stdout handling. All
31 cut fixtures per profile match every corresponding original/pinned hash.
Writer fixtures independently cover empty/partial/full blocks, width/clear
markers and padding. Demand tests cover unused feedback, shared payloads,
EOF non-demand and dictionary reset. Larger full-dictionary behavior is not
certified merely by these selected input profiles. Large SML execution is
claimed only where explicitly recorded.

## References and diagnostic questions

Welch's [compression paper](https://doi.org/10.1109/MC.1984.1659158) supplies
algorithm-family background; the retained source defines this particular writer
and feedback protocol. Trie allocation, shared projections, code-state strictness,
bit operations, string forcing and library arithmetic are source-based questions
until investigated with measurements or compiler inspection. Standard reports
compare identical SML; Haskell supplies correctness references. No historical
performance claim is transferred.

Auxiliary inC files are retained as upstream reference material; the Makefile
selects the Haskell Main workload, and these files have no separate suite run
or fixtures. They are not silently counted as independent runnable imports.
