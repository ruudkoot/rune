# Negative examples

Each file is paired by name with a positive example and contains exactly one
invalid lexical character. Rune-hosted runs must report `invalid character` or
`invalid integer`; native toolchains must reject the wrapped source. The
six-configuration suite is `tests/examples/run_lexer_examples.sh`.
