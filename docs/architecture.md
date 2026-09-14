# Rune architecture

## Current pipeline

The intended execution pipeline is:

```text
Standard ML source -> Rune compiler (Standard ML) -> Rune bytecode -> C VM
```

SML/NJ hosts the first compiler implementation. Poly/ML and MLton check that
the compiler remains portable Standard ML. The C VM is deliberately independent
of the compiler's host representation and consumes only the documented
bytecode contract.

## Repository boundaries

Production implementation lives in `src/sml/` and `src/runtime/`. The
`reference/` tree contains deliberately simpler or independently structured
implementations for comparison. The `prototypes/` tree is for experiments that
may be discarded. Neither tree is a production dependency.

The compiler will eventually be split into modules for source locations,
lexing, parsing, elaboration, typing, intermediate representations, bytecode
emission, and diagnostics. The initial scaffold keeps these boundaries visible
without inventing language semantics prematurely.

## Bytecode contract

The bytecode format is a versioned interface. Before instructions are added,
each instruction must specify its encoding, operand widths, stack effect,
failure modes, and portability assumptions. Integer widths and byte order must
be explicit; C implementation-defined behavior must not define the format.
Every format change requires conformance fixtures consumed by both a producer
and the runtime.

## Bootstrap direction

The initial compiler is built by SML/NJ and emits bytecode for the C VM. Once
Rune has sufficient Standard ML coverage, the compiler may be compiled or
interpreted by Rune itself. That future self-hosting step is not a dependency
of the initial bootstrap path.
