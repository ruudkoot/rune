# minimax provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/minimax.
Copyright 2025 Fellowship of SML/NJ; source and notice retained.

Retains the complete tic-tac-toe rose tree and the separate transposition-table
version with 59049 slots. Each call builds both as upstream. Traverse every
returned node, consuming node count, maximum depth and root score. An
independent exhaustive Python search in `oracle.py` gives a draw (score zero)
and confirms both tree-size/depth fixtures from upstream testit. Normal uses
two calls; large preserves ten. Smoke has recorded 120-second and 2-GiB overrides
because even one call constructs the complete game tree. The 1-GiB
smoke run passed the three reference hosts but Rune reported out of memory;
the larger quota preserves the complete allocation workload.
No cache is reused between separate transposition-table constructions.

Replace the SML/NJ extension `Option.isNone` with `not o Option.isSome`.
The ordinary option list representation, move order and scoring are unchanged.
The read-only traversal is additional measured work; both root scores must
be zero before the six-integer summary reaches the suite's exact checker.
The full tree versus cache-pruned tree distinguishes allocation and lookup
costs. These are source-based hypotheses, not measured explanations.
