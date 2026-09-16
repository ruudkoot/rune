# Rune release notes

## Unreleased — M5b lists

Adds the initial polymorphic `list` type, `nil`, right-associative infix `::`,
and bracket expressions/patterns. Lists use existing nominal datatypes,
matching, equality, value restriction, and collection. The source contract
documents protected constructor names, list type-name shadowing, evaluation
order, and bounded syntax expansion. Multi-clause functions and broader List
Basis operations remain deferred.

Bytecode remains v3 with no VM changes. Existing v3 files remain compatible;
new list bytecode also runs on the M5a VM. User constructor descriptors can
change on recompilation because the initial list constructors reserve IDs first.
The compiler and VM continue to report 0.2.0 until a release is made.

The increment adds 53 fixtures and an executable list-processing example among
them. See [the M5b checkpoint](PLAN.md#m5b--lists-complete) for acceptance
results and environment details. All 236 fixtures pass under all three
host-built compilers on native x86-64 and emulated i386/PowerPC64 VMs, normally
and under GC stress. GCC/Clang sanitizer, build-adapter, and documentation checks
pass. CI has not been run for this working-tree change.

## 0.2.0 — 2026-09-16

M5a adds parameterized recursive datatypes, constructor values and patterns,
`case`, refutable `val`/`fn`/`fun` patterns, and uncaught `Match`/`Bind` failures.
Constructor status follows lexical scope, datatype identity is nominal, and
constructor applications obey the SML value restriction. Datatype equality,
curried pattern timing, bounded exhaustiveness/redundancy warnings, GC tracing,
and source-located failures are covered by the acceptance suite.

Bytecode v3 adds four constructor/matching instructions and extends calls to
unary constructor functions. It preserves the v2 section layout and opcode
numbers 0–33. The VM and disassembler reject v1/v2 and unknown versions;
existing source programs must be recompiled. Compiler and VM report 0.2.0.

Validation passes locally:

- 181 fixtures per Rune host build, normal execution and GC stress, identical
  bytecode and diagnostics, and 47 successful reference programs under all three
  SML compilers. Reference rejections cover 36 SML/NJ and 39 Poly/ML/MLton cases;
  three documented SML/NJ reference exceptions never exempt a Rune build from rejection.
- The same bytecode runs on native x86-64 and QEMU-emulated i386 and PowerPC64
  VMs. Each passes 622 malformed/runtime fixtures in each mode, heap/CLI checks,
  and collector checks including deep constructor graphs and payload roots.
- Strict Clang tests, GCC/Clang ASan/UBSan with leak detection, all three build
  adapters, documentation generation, and Python/MLton syntax/type checks pass.

Lists, multi-clause functions, general type declarations/annotations, handlers,
mutation, records, modules, and broader Basis support remain deferred. See
[LANGUAGE.md](LANGUAGE.md) for exact boundaries and
[the M5a checkpoint](PLAN.md#m5a--datatypes-and-case-complete) for results,
reference-compiler differences, and unverified platforms. CI for this change
has not been run.

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
