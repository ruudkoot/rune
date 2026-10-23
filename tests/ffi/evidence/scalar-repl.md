# Current generated scalar REPL acceptance — 2026-10-23

The earlier release guide omitted dependencies of the final public generator.
Loading only `ForeignBytes`, `ForeignGenerated` and the generated sources now
fails with exit 1 and `unbound type constructor: ForeignOwner.owner`. That exact
old-order command and diagnostic are preserved in `scalar-repl.json`.

This check uses a fresh worktree at **17c471463**, including the final public
generator. Its own production `runeffi.build` was compiled and used to generate
the scalar fixture; no earlier generator artifact was reused. Immutable set:
`7580e5ce5398c8af444beb5f8f5827a11ffc494e18be0f42156e11050eaf2cb0`.

The acceptance coordinator regenerates that fixture, compiles its unchanged C
subject, and asks the compiler for `--basis-deps` with absolute `--lib` and
`--library ffi/runtime`. The returned **14 non-Basis paths** supply UTF-8,
scope, bytes, text, ownership, memory and generated-session helpers in dependency
order. The existing REPL image supplies the Basis, and existing file arguments
load the returned paths followed by generated Raw/public signature/structure
sources. No loader or REPL syntax was added.

Repeated existing `-e` entries then:

1. Open generated public and raw sessions, call each with 20 and 22, require
   public result 42 and raw status bytes 42, and retain prepared native calls.
2. Compile later datatype/value/function declarations, allocate a 7,000-element
   list and call `Runtime.collect ()` while both sessions remain reachable.
3. Require increased collection count and repeat both calls, close both
   sessions, and require `RuneForeign.live () = 0w0`.

**PASS**, normal exit with empty stderr; the final REPL command took 6.054
seconds wall time. Every generation, C compilation,
dependency query and REPL command exited 0; the final REPL printed:

```text
PASS current generated scalar REPL: public=42 raw-status=42 native-resources=0
```

The copied enabled VM has SHA-256
`c8d25daa1abbb9098cfca34ad920df95c3d277b5355b2f166c81721c183ecaa5`.
The compatible existing image has SHA-256
`cd30bec48f70c7251c70ca0b96f0fb1ad2edff177be454bc5f6d097cc223fc3c`.
The scalar gate does not claim that this earlier image exposes subsequently
added Basis members; rebuilding the final release image and checking those
members remains an integration check.

`scalar-repl.json` retains complete argument vectors, dependency order, compiler
and VM identities, generator/subject/source hashes, output and timings. Raw
artifacts are under `tests/out/scalar-repl-final/ffi-scalar-repl/runeo7sWiM/`.
Reproduce with `make test-ffi-repl` on an enabled native Linux/x86-64 build and
a compatible REPL image. Artifact overrides are documented in
[the release guide](../../../docs/ffi/release.md#interactive-use). The corrected
guide also gives the compiler query and complete current source order.

Documentation consistency passed **11/11** in 18.5 seconds, including the
signature/annotation producers and planted-fault checks, with the explicit
compiler override and frozen helper tools in this fresh worktree. The first
attempt lacked that compiler override and failed the signature producer;
that preparation failure remains recorded separately. Edited links, JSON
receipts and `git diff --check` passed. Runner receipts are under
`tests/out/scalar-repl-docs/ready/20261023-120800-8/` (passing) and
`tests/out/scalar-repl-docs/run/20261023-120629-14/` (preparation failure).
