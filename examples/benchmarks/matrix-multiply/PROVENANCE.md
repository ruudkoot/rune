# matrix-multiply

MLton b15e2d289c3d701131733665a74e2dd8438410b6, `benchmark/tests/matrix-multiply.sml`.
Source notice in LICENSE; original and adaptation patch are retained.

Stephen Weeks. Retains Array2 multiplication and dot-product traversal.
Large preserves dimension 500. Every entry is checked against the independent
closed form n*i*j+(i+j)*sum(k)+sum(k*k). The total uses IntInf for narrow
hosts. These inputs produce exactly representable integral doubles.
