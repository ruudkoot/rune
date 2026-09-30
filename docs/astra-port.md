# Safeguards preserved from gpt-6-astra

This change adapts the useful parts of
`46028819d141f5f212a4f5041d60984d34cc4643` to origin/master at
`b30fba275d685600da4d64cf0d9f7288bed0663e`.

- Core `let` expressions reject fresh datatype names in their result and in
  types shared with the surrounding environment. A closure may still capture
  a local datatype when its exposed type does not mention it. Four rejection
  cases agree with both MLton and Poly/ML; another covers mutation of an outer
  argument type when the `let` result itself is an integer.
- Pattern applications retain whether their identifier head was grouped.
  `(C) x` is rejected; `(C x)` and a grouped nullary constructor remain valid.
- Bytecode is written beside its destination and renamed into place only
  after closing successfully. Every explicit input is protected, including canonical
  paths, symlinks, and hard-link aliases. Interrupted writes preserve the
  previous artifact.
- Type inference has a traversal budget per top-level declaration, and
  pattern analysis has a traversal budget per match and a depth bound. The
  defaults and command-line overrides are in [language.md](language.md).
- Structural equality uses an explicit continuation worklist and a per-call
  work budget. Heap growth has an optional semispace ceiling; collection can
  exceed the fill target at the ceiling while an allocation still fits.
  Interpreter, register VM, JIT and native code enforce the same limits.
- Image version 7 records the heap and equality policies. Fork inherits them;
  restore honors the stricter saved or explicitly supplied policy and refuses
  a live heap that cannot fit before allocating it. Version 6 images must be
  recreated. The bytecode format and instruction-set fingerprints are unchanged.

The port imports 103 compatible execution cases with their original output
expectations; [tests/astra.md](../tests/astra.md) records their origins. Tests
depending on Astra's 32-bit default integers, deferred language features or
old syntax limits are excluded. The imported failures also exposed lost or
inconsistent `Match` locations under optimization: their raises now retain
source marks, as `Bind` raises do. The optimization-level comparison checks
the complete output and traces.

Compiler output tests inject a process file-size limit. VM policy tests save
and restore both low and high equality budgets, retain heap ceilings across
restoration, and apply stricter process limits. The language test for saved
heap limits also runs on Windows and across the portability VMs.

The compiler's added traversal accounting increases the bootstrap instruction
count. Its refreshed instruction budget keeps the normal 10 percent headroom;
the existing allocation budgets are unchanged ([performance.md](performance.md)).

## Recorded validation (2026-10-01)

- `make JOBS=8 check` passed: the self-hosted and all six host-built compilers
  pass 325 cases; bootstrap, IR, optimization-level, native, debugger, register
  VM, JIT, Basis, performance, position, reproducibility and documentation checks
  pass. The JIT oracle compares 270 programs; the cross-build oracle compares
  492 programs. Existing explained Basis deviations remain explained.
- The stack sanitizer VM passes all 325 cases and the saved-policy tests.
  `make test-new-asan test-stress` passed, including the GC-stress Basis suite.
- `make test-windows` passed for both widths of both VMs, with 258 language
  programs, 30 loader checks, layout and cross-image tests, and the Basis matrix.
  Additional tests restore the saved heap ceiling on all four Windows VMs and
  exercise the existing stack-VM restore fixtures.
- Portability language, loader, count, layout and cross-image checks passed on
  32-bit x86, big-endian PowerPC and AArch64, including the AArch64 JIT oracle.
  The Basis matrix had one timing-sensitive failure of
  `Posix.Process.sleep/one-second` on `rune:linux32` under concurrent load.
  Its isolated rerun passed all 81 checks of the process and signature tests.
  The other portability configurations had no unexplained failures. The full
  `make test-portability` invocation therefore exited nonzero; it is not recorded
  as an uninterrupted pass.
- Compiler output tests passed with all six hosts and the self-hosted compiler.
  Saved-policy tests also passed through the register/JIT and native runners.
  `git diff --check` passed.
