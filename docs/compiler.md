# Compiler contracts

The compiler is a sequence of independently testable transformations:

```text
source
  -> tokens
  -> parsed AST
  -> elaborated/typed AST
  -> core IR
  -> bytecode
```

Each boundary must have a stable SML signature, explicit ownership of source
locations, and tests for both valid and invalid inputs. A pass must not inspect
private representation details of a previous pass.

## Required contracts

- Diagnostics are structured values containing severity, source span, stable
  code, and human-readable text.
- Source spans use a documented convention and remain valid after buffering or
  normalization.
- IR invariants are stated next to the signature that produces the IR.
- Bytecode emission is total over validated IR; invalid IR is rejected before
  emission.
- Debug output is derived from structured values rather than used as an API.
