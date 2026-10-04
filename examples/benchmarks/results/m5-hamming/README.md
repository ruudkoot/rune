# m5-hamming validation

Recorded 2026-10-04. The shared lazy Hamming stream preserves two signed-64-bit components,
including source overflow at index 88,967. Normal retains the original
skip 88,000/count 200; large uses the original bytecode count 10,000.
Original OCaml and an independent fixed-width cursor oracle agree on every
selected value. Complete large output also passes Rune; broader large host
validation is not claimed. Eight semantic checks pass all ten configurations
at both levels. Earlier forcing-order expectations are intermediate evidence.

[All 24 final primary cases](correctness.tsv) pass smoke/normal
on four Rune engines at both optimization levels and four managed native hosts.
The final matrix compiles canonical suite paths, source order and inputs.

Count archives retain complete samples, source/input/tool snapshots and
configuration identities. Allocations and applicable instruction comparisons
agree. Instrumented times are not headline timing evidence. Initial resolver
races are retained in [the tooling record](../m6-resolver-isolation/README.md).
