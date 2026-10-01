# smith-normal-form provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/smith-normal-form.sml`. Original, adaptation patch and notices retained.

Henry Cejtin integer Smith normal form. Retains the embedded matrix and
IntInf elimination, and consumes every diagonal entry while rejecting
nonzero off-diagonal entries. Profiles use leading 4, 12 and 26 squares;
upstream dimension 35 is still accepted by the driver but not selected.
The previous external runner used 26 to bound intermediate growth.
Review diagonal divisibility and compare the absolute diagonal product with
an independent Bareiss determinant before accepting fixtures.
