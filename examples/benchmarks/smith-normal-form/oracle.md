# Independent matrix check

smoke: Bareiss determinant 7506; gcd of cofactors 1; all invariant magnitudes match.

normal: Bareiss determinant 6096777698704; gcd of cofactors 1; all invariant magnitudes match.

large: Bareiss determinant -60208115211646196979849372947415; gcd of cofactors 1; all invariant magnitudes match.

Bareiss fraction-free elimination uses the unchanged leading matrix squares.
Cofactor gcd 1 implies the first n-1 invariant factors are units. Signs are
the algorithm-specific fixture from the retained SML source; absolute factors
and off-diagonal zeros have independent algebraic checks.
