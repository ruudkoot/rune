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

The first implementation is intentionally a small expression compiler. It
accepts integer and boolean literals, arithmetic and comparison, conditional
expressions, `let val` bindings, and sequencing. It is hosted by SML/NJ and
must also compile as Standard ML with Poly/ML and MLton; function declarations,
modules, and self-hosting are later milestones.

## Source modules

The bootstrap compiler keeps each phase in its own Standard ML module:

- `ast.sml` defines the expression tree and operator vocabulary.
- `lexer.sml` converts source text into tokens.
- `parser.sml` builds an AST using expression precedence.
- `tycheck.sml` checks the AST before code generation. The only current types
  are `int` and `bool`; arithmetic and ordered comparisons require `int`,
  equality requires matching operand types, `if` conditions require `bool`,
  and both branches must have the same type. A `let val` extends the lexical
  environment, and sequencing has the type of its second expression.
- `emit.sml` translates checked expressions to version-1 bytecode.
- `rune.sml` is the public orchestration module and retains the
  `RuneCompiler.compile` API.

The modules are loaded in this dependency order by the SML bootstrap and
listed explicitly in the MLton check. Invalid syntax, unbound variables, and
type errors are reported as failures before emission.

## Required contracts

- Diagnostics are structured values containing severity, source span, stable
  code, and human-readable text.
- Source spans use a documented convention and remain valid after buffering or
  normalization.
- IR invariants are stated next to the signature that produces the IR.
- Bytecode emission is total over validated IR; invalid IR is rejected before
  emission.
- Debug output is derived from structured values rather than used as an API.
