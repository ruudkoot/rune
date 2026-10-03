# Persistent structures and graph conversion

Recorded 2026-10-03. Five ports cover lazy/strict relation-tree joins,
lazy/strict dictionary checking, and Mark P. Jones's common-subexpression
elimination example. The suite contains 177 programs and 525 profiles.
M3 remains in progress.

[The attempt ledger](correctness-attempts.tsv) records 155 attempts, including
the initial CSE port error: an unconstrained tuple selector compiled on Rune
but was rejected by native hosts. The portable closed tuple pattern fixes
that error. All 80 required final Rune smoke/normal cases pass across four
engines and two optimization levels. The primary four managed native hosts
also pass both profiles. No universal large-profile execution is claimed.

Original GHC observers and independent relational joins, dictionary membership,
and bottom-up subtree interning confirm the fixtures. Treejoin tests check
lookup boundaries, duplicate rejection, and demand of unmatched fields.
Word-set tests check balance, cached sizes, duplicates, missing entries,
Latin-1 whitespace, and exact tree shape against containers 0.6.7. Both
semantic targets pass all ten configurations at both Rune optimization levels.

The separate count archives retain complete samples, source/input snapshots,
configuration metadata, and raw observations. Allocation counts agree across
all four Rune engines, and instruction comparisons agree within the applicable
stack/native and register/JIT pairs. Instrumented times are not headline
performance comparisons. Compiled payloads and disposable working directories
are excluded from these archives.

The complete repository acceptance transcript is recorded in
[validation](../../validation/oct03-persistent-acceptance.log).
