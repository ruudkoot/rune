# knuth-bendix provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/knuth-bendix.sml`. Original, adaptation patch and notices retained.

Knuth-Bendix term-rewriting completion (individual author not stated in this source), from the SML/NJ collection
through MLton. The geometric group equations and recursive path order are
unchanged. Return completed rules instead of discarding them, normalize both
sides of every input equation, and consume the exact completed rule text.
Retains rule ordering and numbering; correctness references cover this
problem, not arbitrary completion termination.
