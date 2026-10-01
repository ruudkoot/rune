# zebra provenance

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/zebra.sml`. Original, patch and notice retained.

Stephen Weeks, 1999 zebra puzzle constraint solver. Retains generative
exceptions, fluid state and consistency propagation. The observed count of
3342 attempted assignments is asserted by upstream and returned per search.
Large preserves one original driver batch (its inclusive loop ran 1001).
This fixture checks control flow; additional solution constraints are required
before using it to claim a general constraint solver correctness result.
