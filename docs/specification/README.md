# Rune language specification

This directory is the semantic source of truth for Rune. Organize the
specification by feature rather than by compiler phase. Each feature should
state syntax, static semantics, dynamic semantics, diagnostics, examples, and
conformance status.

The initial target is Standard ML compatibility. Rune-specific extensions must
be marked explicitly and must not silently change the meaning of Standard ML
programs.

## Required feature record

Every supported feature should identify:

- the specification section and status in `features.yaml`;
- accepted and rejected examples;
- implementation phases that own it;
- reference implementations used for comparison;
- known deviations or implementation-defined behavior.
