# smith-normal-form-mlkit provenance

mlkit `6dab5582db22a5f5672ca1fc5244171687d83ce5`, `test/smith-normal-form.sml`.
Henry Cejtin. Original modules/individual headers, aggregate notice and patch
are retained.

Keep the source matrix abstraction, arbitrary-precision Euclidean row/column
operations and the complete original integer table. Parameterize its selected
leading dimension, check every off-diagonal zero and consume every actual
signed diagonal entry. Large preserves dimension 32 and 1 calls.
Fixtures are reviewed native original reductions. Their absolute diagonal
product agrees with independent fraction-free Bareiss determinants; gcd-one
cofactor witnesses and diagonal divisibility verify the invariant factors.
Signed factors preserve the original reduction output.
The MLton source instead selects dimension 35. IntInf is never replaced
by machine arithmetic. Allocation/representation are source hypotheses,
not measured causes; see [arithmetic literature](../literature.md).
