# Sequential dense-array Life

Recorded 2026-10-16. [26 smoke/normal cases](correctness.tsv) pass on four Rune
engines at both levels and five managed native SML hosts. The two native32
attempts in the [ledger](correctness-attempts.tsv) reproduce the already isolated
SML/NJ generator Overflow; no alternate source or expected board is accepted.
Ten rule, boundary, buffer-isolation and actual-checker tests pass all ten
configurations at both levels. All four Rune normal count samples pass and
allocation/applicable instruction comparisons agree.

The kernel keeps exception-based zero exterior, all eight reads, row/column
order, two buffers and swaps. Both final buffers remain live through full cell
validation. Original OCaml and independent stencil calculations agree on smoke/
normal current and previous boards. All initial boards, including original large,
agree with an independent implementation of the pinned generator.

Normal 64/128 is practical; large 256/1024 preserves the published invocation.
Generation/checking, generic row arrays and lifetime details are explicit.
No universal large SML or headline timing claim is made. M5 remains in progress.
