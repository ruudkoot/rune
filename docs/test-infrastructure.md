# Test infrastructure

The test runner should emit machine-readable records with:

```text
suite, case, category, status, duration, toolchain, diagnostic
```

Statuses are `pass`, `fail`, `skip`, and `error`; a skipped optional toolchain
must never be reported as a pass. Every test case should be runnable by stable
name and should preserve its input and expected output on failure.

Future generators should support deterministic seeds and failure shrinking.
Metamorphic tests should record the relation being checked, not only the two
outputs. Fuzzing belongs behind time and resource limits so it can run in CI.

Golden files are reviewed artifacts. A deliberate update must use an explicit
regeneration command and a comparison that detects stale generated output.
