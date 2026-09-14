# Testing policy

Tests are organized by the behavior they protect:

- `tests/unit/` checks local module invariants.
- `tests/examples/positive/` checks accepted programs and expected output.
- `tests/examples/negative/` checks rejected programs and diagnostics.
- `tests/regression/` preserves fixes for previously observed failures.
- `tests/reference/` compares production behavior with executable oracles.
- `tests/bytecode/` checks encoding and VM conformance.
- `tests/performance/` records repeatable workloads and thresholds.

A test should state whether it is a positive, negative, correctness,
regression, performance, or reference-comparison test. Fixtures belong beside
the category that owns their meaning. Test runners must distinguish a skipped
optional toolchain from a passing implementation check.

The production compiler and C VM are tested independently and end-to-end.
Reference implementations are evidence, not authority: when behavior differs,
the intended Standard ML behavior and its documentation must decide which side
changes.
