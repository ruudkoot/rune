# The weak points of Rune

A review of 2026-09-24, on the `codegen` branch at `ceec671`. It ranks
what holds Rune back most, first by how much it costs a user and then by
how often a user runs into it.

Rune is strong where it has been tested hardest: the whole language of the
Definition, the whole Basis Library, a compiler that compiles itself, the
same bytecode from five builds, and documentation that the test suite
checks. Almost every weak point below is about speed or everyday use, not
correctness.

Every item says where Rune is now, what shows it, and a first step. Timings
from this review are the best of five runs, wall time, on a quiet machine;
the others are from [performance.md](performance.md).

## 1. Every compile starts from source, and there are no project files

* **Now:**
  * The files of the Basis Library that a program names are compiled
    again with every program, and the whole program is compiled at once.
  * A project is an ordered list of files on the command line. Rune reads
    neither MLton's `.mlb` files nor SML/NJ's `.cm` files (`rune --help`).
* **Shown by:** a program of two lines that uses `List` and `TextIO`:

  | Compiler | Time | Output |
  |---|---:|---:|
  | `bin/rune` (the compiler Rune ships) | 1.8 s | 203 KB |
  | `bin/rune-mlton` | 0.1 s | 203 KB |

  `examples/hello.sml`, which loads almost nothing, takes 0.05 s.
* **Why it comes first:** every user meets it on every compile. Existing
  SML projects must be put into one list of files by hand before Rune can
  build them. A REPL (item 4), a language server, incremental builds and
  libraries of Rune's own all need a compiler that can keep what it has
  compiled.
* **First step:** compile the Basis Library once and keep the result: the
  elaborated environment and the bytecode of each file of
  `lib/basis/MANIFEST`. Then read `.mlb` files.

## 2. There is no optimiser, so programs run slowly

* **Now:** the compiler translates straight to bytecode.
  * Half of all instructions move values between slots.
  * Every call passes one boxed argument, so a third of all calls build a
    new tuple.
  * The collector copies long-lived data again at every collection.
* **Shown by** ([performance.md](performance.md)):
  * Native code is 8 to 11 times slower than MLton's; `runevm` is 17 to
    157 times slower (`tak` 80 times, `word_bits` 157 times).
  * The collector takes 27% of the time of native code.
  * The compiler Rune ships is the bytecode one: compiling itself, it
    takes 7.3 s on `runevm` against 0.30 s for the MLton build.
* **First step:** the ranked list of [performance.md](performance.md).
  Items 1 to 3 are measured and not built: 16.5% fewer instructions in the
  bootstrap, and the trials changed about 60 lines. Items 1 to 12 are all small (S or S-M).
  The large ones are 13, a generational collector, and 14, direct calls to
  known functions with n arguments.

## 3. Error messages

* **Now:**
  * `Error.error` raises `CompileError`, which the driver catches once
    (`src/driver/main.sml:163`), so the compiler stops at the first error.
  * An error is a span and a string (`src/util/error.sml`); the owner's
    notes already ask for a datatype of errors instead.
  * A message gives no line of the source.
* **Shown by:**
  * A file with three errors (a type mismatch, an unbound `g`, a wrong
    annotation) reports one.
  * `fun f x = case x of 0 => "a" | n => n` gives:

    ```
    error: result of match rule: type mismatch between string and int
    (no common type for overloaded operators (string vs int))
    ```

    The program has no overloaded operator; `0` is an overloaded constant.
  * `fun f x = x + 1  val a = f "hello"` gives:

    ```
    error: function argument: type mismatch between int and string
    (type constructor mismatch: string vs int)
    ```

    The two halves give the types in opposite orders, and neither says
    which type was expected and which was found.
* **First step:** a datatype of errors, so that the text of a message is
  made in one place, with "expected ... found ..." for every mismatch and
  the line of the source under the span. Then recover after an error at the
  next top-level declaration, so that one run reports every independent
  error.

## 4. There is no REPL

* **Now:** Rune compiles files and nothing else.
* **Why it matters:** SML/NJ and Poly/ML are mostly used interactively,
  and HOL4, which the owner wants to run, needs a REPL.
* **First step:** item 1's compiler that keeps what it has compiled. A REPL
  is that compiler, taking one top-level declaration at a time, with a VM
  that keeps its heap and globals between them.

## 5. Little testing on code Rune did not write, and no CI

* **Now:**
  * The largest programs Rune has compiled are its own tools (`runedoc`,
    the largest, is about 9,600 lines; the compiler about 6,200) and the
    Basis Library, about 20,500.
  * The only outside programs are MLton's regression programs
    (`tests/external/run-mlton.sh`, 93 of them skipped, 62 of those for
    MLton's extensions) and the harness of `rune-corpus-sml97`, about 1,800
    lines, which is at its first milestone.
  * No large codebase written by others (smlnj-lib, cmlib, MLton's own
    sources, HOL4) has been built with Rune. How Rune behaves at that size,
    in its bugs and in its speed, is not known.
  * There is no `.github/` directory. Every check runs by hand on one
    machine under WSL, and `make test-windows` and `make test-portability`
    are outside `make check`.
* **First step:** build one large outside codebase and fix what breaks;
  xc2 ([fourth-quadrant.md](fourth-quadrant.md), MLton's Basis compiled by
  Rune) is one, already measured. Separately, a CI job that runs
  `make check` on every push.

## 6. Missing runtime features

* No threads and no Concurrent ML.
* No way to call C: the VM has a fixed set of primitives (`vm/prims.def`).
* No signals: Ctrl-C ends the program, so `SML90.Interrupt` is never raised
  ([limitations-review.md](limitations-review.md)).
* A simple two-space (Cheney) collector, and every value takes 16 bytes
  ([performance.md](performance.md), items 13 and 19).

## 7. Every change to the VM costs a lot

* **Now** ([AGENTS.md](../../AGENTS.md), *Native code*):
  * One instruction lives in `vm/interp.c`, `src/opt/x64.sml`,
    `src/opt/rbccheck.sml`, `vm/native.c` where it calls C,
    `docs/bytecode.md` and `tests/opt/every-opcode.rasm`.
  * The common case of 56 primitives is written twice, once in C
    (`vm/prims.c`) and once as x86-64 code (`fastPrim`).
  * The templates copy the push and pop of a frame and the fast path of
    `vm_alloc`, so a change to either is made twice.
* **Why it matters:** items 13, 14, 16 and 17 of
  [performance.md](performance.md) each add to this. Item 14 alone is a
  second calling convention in four implementations.
* **First step:** before starting those items, decide whether an
  intermediate representation with an optimiser should come first and emit
  to both back ends, so that the work is done once.

## 8. Few platforms

* **Now:**
  * Linux is the main platform.
  * Windows has only the VM, cross-built with mingw-w64 and tested
    through WSL; the compiler and the tests are compiled on Linux
    ([building.md](../building.md)). `OS.Path` is the one of POSIX there,
    so a drive comes back as `/C:/...`.
  * Nothing is built or tested on macOS.
  * Native code is for x86-64 Linux only ([native.md](../native.md)).
* The 32-bit x86 and big-endian PowerPC VMs of `make portability` are a
  strength, not a gap: they show that the VM is portable. What is missing
  is the rest of the toolchain on those systems.

## 9. No ecosystem and no tools

* No libraries beyond the Basis Library.
* No language server of Rune's own. `millet.toml` points Millet, a
  third-party language server, at `build/rune.mlb`, the build file
  made for MLton; Millet checks a program against its own Basis Library,
  not Rune's.
* No formatter and no package manager.

## Not on the list

* **`Real32`** (the owner's notes call it "fake"): a value is a `real` that
  binary32 can represent, and every operation rounds its result to binary32
  (`lib/basis/real32.sml`). For `+`, `-`, `*`, `/` and `Math.sqrt` that is
  the correctly rounded result. The rest of `Math` is computed in double
  and rounded once to binary32. It behaves as binary32; only the way it is
  stored is not.
