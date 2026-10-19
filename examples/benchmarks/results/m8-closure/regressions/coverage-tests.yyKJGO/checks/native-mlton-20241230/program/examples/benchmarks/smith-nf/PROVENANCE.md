# smith-nf provenance

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/smith-nf`.
Henry Cejtin. Original modules/individual headers, aggregate notice and patch
are retained.

Keep the source matrix abstraction, arbitrary-precision Euclidean row/column
operations and the complete original integer table. Parameterize its selected
leading dimension, check every off-diagonal zero and consume every actual
signed diagonal entry. Large preserves dimension 33 and 5 calls.
Fixtures are reviewed native original reductions. Their absolute diagonal
product agrees with independent fraction-free Bareiss determinants; gcd-one
cofactor witnesses and diagonal divisibility verify the invariant factors.
Signed factors preserve the original reduction output.
The MLton source instead selects dimension 35. IntInf is never replaced
by machine arithmetic. Allocation/representation are source hypotheses,
not measured causes; see [arithmetic literature](../literature.md).

The upstream dimension-33 Main expected literal is stale: it gives
`~1027954043102083189860753402541358641712697245`, while its actual
table/reduction gives `~174455975010120216862039859605035043439271`.
The independent determinant and cofactor check support the latter. The
full signed diagonal is retained rather than copying the stale literal.
