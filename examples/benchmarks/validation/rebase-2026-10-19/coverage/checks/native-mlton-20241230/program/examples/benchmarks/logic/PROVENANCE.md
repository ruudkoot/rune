# logic provenance

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/logic.sml`. Original, patch and notice retained.

SML/NJ continuation-based unification and backtracking for peg solitaire.
Retains the original board and first-solution stopping condition. Returning
normally without reaching the success continuation fails validation, unlike
the original driver. Upstream testit independently reports yes for this board.
