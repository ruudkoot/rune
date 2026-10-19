# logic-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/logic.
Ordered original sources, notice and adaptation patch retained.

Modern modular peg-solitaire unification/backtracking workload. Retains
Term, Trail, Unify and Data source order, first-success continuation and
original board. Normal preserves sixty solves. A normal return without
reaching the success continuation fails; the actual success count is
consumed. Separate from MLton's concatenated earlier variant.
