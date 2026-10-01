# boyer provenance

MLton `b15e2d289c3d701131733665a74e2dd8438410b6`,
`benchmark/tests/boyer.sml`. Project notice: LICENSE.

Classic SML/NJ tautology checker. Terms, rewrite rules, property lists,
substitution and theorem are retained. Unlike the original unit driver, every
returned theorem result must be true. The same theorem appears in upstream
Main.testit as Proved. This observes the actual computation without adding
a second theorem invocation. The repetition count is runtime input.

The unmodified source and separate adaptation patch accompany the port.
