# Rune release notes

## 0.1.0 — 2026-09-16

Rune's first v0.1 functional subset completes M0–M4. It supports typed expressions,
sequential `val`/`let` bindings, first-class lexical closures, curried and recursive
functions, tuples, irrefutable patterns, and let polymorphism with the SML value
restriction. The C VM provides tail calls, checked 32-bit integer arithmetic,
byte strings, and non-moving garbage collection with a bounded managed heap.
See [LANGUAGE.md](LANGUAGE.md) for the full contract and implementation limits.

M4 adds `make test-portability`, which runs the same bytecode from all three
host-built Rune compilers on native x86-64 Linux, 32-bit i386 Linux, and
big-endian PowerPC64 Linux. The latter two targets run under QEMU user emulation.
Target checks verify the architecture, pointer width, and byte order before the
collector and semantic suites run. CI includes this matrix and strict Clang and
GCC/Clang sanitizer checks. [BUILD.md](BUILD.md) documents setup and commands.

### Validation

- Clean `make test-all`: 133 fixtures per host, normal and GC-stress execution,
  identical bytecode and rejection diagnostics, and agreement with 33 reference
  programs and 15 reference rejection cases under SML/NJ, Poly/ML, and MLton.
- `make test-portability`: all three compiler builds against all three VMs;
  identical stdout, status, and runtime diagnostics from the same bytecode files.
  Each VM passes 372 malformed-bytecode/runtime cases in each execution mode,
  CLI checks, and the collector's roots, cycles, deep-graph, and heap-accounting
  checks.
- Build-adapter checks, strict native Clang tests, GCC and Clang ASan/UBSan suites
  with leak detection, documentation checks, and Python syntax checks pass.
- [GitHub Actions for implementation commit `fed2c2e`](https://github.com/ruudkoot/rune/actions/runs/35030873753)
  passes both `compiler-and-vm` and `vm-portability` jobs. The subsequent release
  documentation update is checked locally.

### Compatibility and remaining scope

The language subset and bytecode v2 encoding are unchanged from Rune 0.0.3.
Existing v2 bytecode runs without recompilation; v1 and unknown versions remain
rejected. Compiler and VM version strings now report 0.1.0.

Lists, datatypes, constructor patterns, `case`, user exceptions, mutable storage,
records, modules, and broader Basis support remain deferred to M5. Other OSes,
ARM64, native PowerPC hardware, and 32-bit big-endian targets remain unverified.
The VM is not a hostile-code execution sandbox. The
[implementation checkpoint](PLAN.md#implementation-checkpoint--2026-09-16)
records environment workarounds and the next milestone.
