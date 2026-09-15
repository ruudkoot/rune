# Rune

Rune is a planned Standard ML ’97 compiler, written in portable Standard ML,
that emits bytecode for a portable C virtual machine.

## Status

This repository currently contains the implementation plan and proposed language
contract. The compiler, VM, and build targets have not been implemented.

- [Implementation plan](docs/PLAN.md): milestones, architecture, builds with
  SML/NJ, Poly/ML, and MLton, and acceptance checks.
- [Language support](docs/LANGUAGE.md): current status, proposed subsets,
  semantics, and exclusions.
- [Contributor instructions](AGENTS.md): requirements for keeping implementation,
  language documentation, and tests in sync.

The first implementation milestone will compile a small, statically typed subset
to bytecode and run it on the C VM. Later milestones add polymorphic functions and
closures, then more of SML ’97. Self-hosting is a later goal.

## Planned build interface

These commands are the interface to implement; they are not available yet:

```sh
make HOST=smlnj build
make HOST=polyml build
make HOST=mlton build
make all-hosts
make test-all
```

Each host will produce a `build/<host>/rune` launcher. All three will emit the
same bytecode format for `build/vm/rune-vm`.
