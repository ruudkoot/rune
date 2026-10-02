# boyer provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/boyer.sml`. Project notice: LICENSE.

Classic SML/NJ tautology checker. Terms, rewrite rules, property lists,
substitution and theorem are retained. Unlike the original unit driver, every
returned theorem result must be true. The same theorem appears in upstream
Main.testit as Proved. This observes the actual computation without adding
a second theorem invocation. The repetition count is runtime input.

The unmodified source and separate adaptation patch accompany the port.

ML Kit test/boyer.sml at 6dab5582db22a5f5672ca1fc5244171687d83ce5
shares the complete same kernel, theorem, substitution and rules. Its
original wrapper repeats fifty times and prints a progress dot; the canonical
parameterized driver accepts that count and records suppression of progress
output. The additional pristine source is retained here.
