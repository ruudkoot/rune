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

## Lexer example corpus

`tests/examples/run_lexer_examples.sh` runs paired positive and lexical
negative examples against six configurations: native `smlnj`, `polyml`, and
`mlton`, plus `rune-smlnj`, `rune-polyml`, and `rune-mlton`. Native
configurations compile a generated top-level SML wrapper. Rune configurations
load the production compiler modules and call `RuneCompiler.compile` through a
generated driver.

Positive cases must compile in every available configuration. Negative cases
must be rejected by native toolchains and must produce the stable lexer
diagnostics `invalid character` or `invalid integer` in Rune configurations.
Unavailable toolchains produce `skip` records rather than passes. Run the
corpus directly with `make check-lexer-examples`.

Golden files are reviewed artifacts. A deliberate update must use an explicit
regeneration command and a comparison that detects stale generated output.
