# The weak points of Rune

A review of 2026-10-11, on `master` at `dae754d7`, refreshing the one of
2026-09-24 (`ceec671`). It ranks what holds Rune back most, first by how
much it costs a user and then by how often a user runs into it. What was
done since the last review, or dropped, is in the last section.

In the seventeen days between the two reviews, 309 commits landed:

* a middle end;
* a register VM with a JIT;
* 8-byte values and a generational collector;
* compiled units with a cache;
* a REPL with a debugger;
* the Basis libraries of four other compilers, MLton's sources and HOL4,
  all compiled by Rune.

Rune is no longer slow at everything, and it has a REPL. What is weak now
is mostly what that pace left behind:

* the tests and CI do not check what Rune ships;
* programs still run several times slower than under MLton;
* large programs written with many functors take minutes to elaborate;
* a change to the runtime touches more places than it did.

Every item says where Rune is now, what shows it, and a first step. Timings
marked *measured here* were taken for this review on a fresh build of
`dae754d7` in a scratch copy: the best of five runs, wall time, with a load
average of about 3. The others name the document they come from and the
date it gives.

## 1. The tests and CI do not check what Rune ships

* **Now:**
  * Rune ships `bin/rune`, which makes register bytecode, and
    `bin/runevm`, which runs it with the JIT at tier 2 (`--jit=opt`).
  * But `make test` and most suites still run the stack VM:
    `RUNEVM ?= bin/runevm-stack`, with the compiler pinned to
    `--target=stack` (`Makefile:86-92`). Only `test-register` and
    `test-register-jit` cover the shipped engine.
  * On 2026-10-09 the owner decided that the register VM is the default
    for everything and the stack VM only an oracle for it. The Makefile has
    not changed to match.
  * CI (`.github/workflows/check.yml`, since 2026-09-25) runs `make check`
    on Linux x86-64 only. These are checked by hand, if at all:
    * Windows;
    * the 32-bit and PowerPC VMs;
    * the aarch64 JIT;
    * xc2;
    * MLton's sources;
    * HOL4.
  * The `check` run on master failed after the merge of `incremental` (#38)
    and again after the merge of `repl` (#39), in `test-doc`
    (`lawerrors.lib.diag`). Both pull requests were merged with their own
    runs failing.
  * `make check` takes about a quarter of an hour on 16 CPUs (`AGENTS.md`),
    against 3 minutes at the last review. `make test-windows` takes about
    15 minutes more.
* **Shown by:** a bug in the JIT's tier 2, found by the xc2 configurations
  and not by `make check`. Under `RUNE_INT64`, a register kept a box's
  address across a minor collection. It was fixed on 2026-10-09
  (`75192718`). Its test, `make test-int64`, is still outside `make
  check`, as are the `rawhomes`, `conv` and `realboxed` builds.
* **Why it comes first:** a wrong result from the engine that ships is the
  worst thing a user can meet, and it is where Rune changes fastest. The
  register runtime and its JIT are about 9,400 lines of new C.
* **First step:**
  1. Make master green, and merge nothing whose run is red.
  2. Point the default suites at `bin/rune` and `bin/runevm`, and keep the
     stack VM as the oracle.
  3. Add the suites of the other machines to CI, nightly if they are too
     slow for every push.

## 2. Programs run four to eight times slower than under MLton

* **Now:**
  * The middle end optimises at `-O1` ([ir.md](../ir.md)), and the JIT's
    tier 2 keeps ints, words and reals in registers.
  * But a call in `fib` is still 84.5 machine instructions, against about
    17 for MLton.
  * Values are written to memory with their tags, and compiled code keeps
    the counter of `--count` ([performance.md](../performance.md)).
  * `IntInf` is lists of 30-bit limbs in SML.
* **Shown by** ([performance.md](../performance.md), 2026-10-02):
  * The programs of `tests/perf`, on the VM Rune ships, against MLton:

    | Program | Against MLton |
    |---|---:|
    | `array_sieve` | 4.7x |
    | `fib` | 4.0x |
    | `tak` | 3.9x |
    | `string_ops` | 3.7x |
    | `word_bits` | 3.6x |
    | `list_ops` | 1.4x |
    | `real_nbody` | 0.9x |
    | `intinf_fact` | about 790x |

  * The benchmark suite has 69 programs long enough to time. Together they
    take 7.8 times as long as under MLton, and MLton is faster on every
    one. Without `mandelbrot-rat` (214x, all `IntInf`) and `mpuz` (18x),
    the rest take 5.6 times as long.
  * HOL4 against Poly/ML ([hol4.md](hol4.md), 2026-10-09):

    | | Against Poly/ML |
    |---|---:|
    | theories | 3.7x to 5.2x |
    | `EVAL` | 6x to 7x |
    | `PROVE_TAC` | 10x |
    | the build through `src/boss`, processor time | 3.4x |

  * The compiler compiling itself: 3.04 s, against 1.12 s for MLton's
    build (2.7x).
  * These tables predate the 8-byte values, which took off about 15% since
    ([heap-layout.md](heap-layout.md)), and the new collector, which
    changed little ([garbage-collector-v2.md](garbage-collector-v2.md)).
* **First step:**
  1. Re-time `docs/performance.md`.
  2. Then the GMP roadmap ([gmp.md](gmp.md)), which removes the outliers
     of 200 times and more at once.
  3. Then the cost of a call at tier 2 and pointers in registers (stack
     maps), which the JIT leaves open.

## 3. Large programs elaborate slowly, and existing projects must be translated

* **Now:**
  * The front end reads 50,000 to 80,000 lines a second on ordinary code.
    It is slow on two things:
    * signatures that share large structures;
    * functors applied many times, whose bodies are elaborated again in
      full at every application.

    ([incremental-compilation.md](incremental-compilation.md), M1.)
  * Rune reads its own build files (`--build`, [build.md](../build.md)).
    They mean what MLton's `.mlb` files mean, in a syntax of Rune's own.
    Rune reads no `.mlb` file and no `.cm` file:
    * MLton's sources were compiled from a flat list of files;
    * HOL4 was built through a script that flattens its `.mlb` files.
  * The compiled Basis (`lib/cache`) is used by `--units`, `--build`, the
    REPL and `use`. A plain `rune prog.sml` does not use it: it compiles
    from source the Basis files the program needs, every time.
  * For a small program the cache gains nothing (*measured here*): a
    two-line program takes 0.32 s from a warm cache and 0.31 s from
    source. M6's own target for it was not met
    ([incremental-compilation.md](incremental-compilation.md), *What is
    left*).
* **Shown by:**
  * MLton's compiler, 606 files and 198,458 lines (2026-10-09):
    * 625 s, of which 611 s is elaboration: 335 lines a second.
    * 135 s even under MLton's build of Rune, so the time is the
      elaborator's, not the VM's.
  * Compiling the compiler in units gets no faster with `-j`: 5.63 s at
    `-j 1`, 6.04 s at `-j 16`.
  * Building MLton in units without the cache peaks at 3.3 GB, which is not
    explained.
* **First step:**
  1. Profile signature instantiation, sharing, and the elaboration of
     functor bodies on MLton's sources. *Ready for, not built* in
     incremental-compilation.md lists this.
  2. Then a reader of `.mlb` files that makes the build files' model.

## 4. Every change to the runtime costs more than it did

* **Now** ([AGENTS.md](../../AGENTS.md)):
  * Much that was written by hand is now generated, from the instruction
    set described in SML (`src/isa`):
    * the interpreters' cases;
    * the stack effects;
    * the opcode tables;
    * the JIT's cases.

    The layout of a value is in `runtime/value.h` and `masm.c` alone.
  * But there are more engines, and all of them must agree on the output
    and on `--count`:
    * the stack VM;
    * the register interpreter;
    * the JIT's two tiers on x86-64 (System V and Win64) and on aarch64;
    * `runeopt`;
    * two collectors, with compaction;
    * four Windows VMs and the five of `make portability`.
  * A primitive's common case can be written in four places:
    * `runtime/prims.c`;
    * `fastprim.h`, about 110 of them;
    * the JIT's inline primitives, about 120;
    * `runeopt`'s `fastPrim`, 60.

    At the last review, 56 were written twice.
  * The C runtime grew from about 9,800 lines to about 30,700, of which
    about 4,900 are generated. The largest parts:
    * the JIT, 6,300;
    * the system layers, 5,600;
    * the collectors, 3,400.
* **Why it matters:**
  * `make check` went from 3 minutes to 15 (item 1).
  * Each engine is one more configuration for a bug to hide in, as the
    tier-2 bug did.
* **First step:** decide whether `runeopt` stays, now that the register VM
  and its JIT are what Rune ships.
  * Its code is about as fast as tier 2: 3.12 s against 3.04 s for the
    compiler compiling itself.
  * Retiring it would remove one engine and one copy of 60 common cases.

## 5. Error messages say less than they could

* **Now:**
  * The elaborator recovers at the next top-level declaration, so one run
    reports every independent type error (incremental M2).
  * On a terminal, each error shows its source with carets
    ([diagnostics.md](../diagnostics.md), repl M2).
  * A syntax error still ends the compile ([units.md](../units.md)).
  * A name that a failed declaration would have bound is then reported as
    unbound too.
  * An error is still a span and a string (`src/util/error.sml`).
  * The text of a mismatch is unchanged (`src/elab/unify.sml:54,122,137`).
* **Shown by** (*measured here*): `fun f x = x + 1  val a = f "hello"`
  gives

  ```
  err1.sml:2:11: error: function argument: type mismatch between int and string (type constructor mismatch: string vs int)
    |
  2 | val a = f "hello"
    |           ^^^^^^^
  ```

  * The two halves still give the types in opposite orders, and neither
    says which type was expected.
  * `fun f x = case x of 0 => "a" | n => n` still says "no common type for
    overloaded operators", though the program has no operator. *Fixed on
    2026-10-13:* two overloaded types of one kind each, such as those of
    two constants, now clash as "type constructor mismatch: string vs
    int". An operator used at a kind it lacks gives "overloaded operator
    not defined at type char", as it already did at a type that is not
    overloaded.
* **First step:**
  1. A datatype of errors, with "expected ... found ..." for every mismatch.
     [errror-messages.md](errror-messages.md) is the brief.
  2. Then recovery in the parser.

## 6. Missing runtime features

* **No threads,** green threads or Concurrent ML: "there is no second
  thread" (`docs/runtime.md`).
  * HOL4 on Rune runs without its threads ([hol4.md](hol4.md)).
  * The threads roadmap was to be drafted after heap-layout's M7
    ([heap-layout.md](heap-layout.md)). It has not been.
* **No way to call C:** the primitives are a fixed set, 387 of them now
  (`src/isa/prims.sml`).
  * heap-layout's M8 laid groundwork: a handle table and arrays laid out
    as C's.
  * There is no roadmap for a foreign function interface.
* **No asynchronous I/O** beyond `OS.IO.poll` and the non-blocking socket
  calls. [async-io.md](async-io.md) is a brief of one line.
* **One signal only:** no signal but the interrupt has a handler, and
  `Posix.Signal` only names the others.
* **No interrupt in native code:** the code of `runeopt` never polls, so
  an interrupt never reaches it (`docs/runtime.md`).
* **First step:** the threads and FFI roadmaps that heap-layout promised.

## 7. Few platforms

* **Now:**
  * Linux on x86-64 is the main platform, and the only one in CI.
  * On Windows, these run, all tested through WSL:
    * the VMs: four of them, cross-built with mingw-w64;
    * the JIT;
    * the REPL;
    * the debug adapter;
    * the Jupyter kernel.
  * What Windows still lacks:
    * The compiler alone, `bin/rune`, is not run there
      ([building.md](../building.md)).
    * `OS.Path` is still POSIX's, so a drive comes back as `/C:/...`.
  * The JIT also makes aarch64 code, for Linux only. It runs under qemu
    and has never run on real hardware or been timed.
  * There is nothing for macOS: no `__APPLE__` in the code. The JIT's
    `MAP_JIT` is only "noted for when there is a Mac" ([jit.md](jit.md)).
  * The 32-bit VMs only interpret. The native code of `runeopt` is for
    x86-64 Linux only.
* **First step:**
  1. A macOS build on an arm64 machine, which would also run the aarch64
     JIT on hardware.
  2. Then `OS.Path` for Windows.

## 8. Not ready for other people to use

* **No licence:** the repository has no `LICENSE`, so nobody else may use,
  change or redistribute Rune. This is the cheapest item on the list, and
  only the owner can do it.
* **No language server:**
  * `rune --serve` is a JSON-RPC prototype with diagnostics and hover,
    not LSP (`src/driver/serve.sml`).
  * `rune-ide` is an Electron IDE with a service of its own. Its hover and
    definitions are not started.
  * `millet.toml` still points Millet at a build file made for MLton.
* **No formatter.**
* **No package manager:** a survey and a sketch of a lock file wait for
  the owner ([incremental-compilation.md](incremental-compilation.md),
  M12).
* **First step:**
  1. A licence.
  2. Then `--serve` as LSP, which every editor can use.

## 9. The prose falls behind the code

`make check-docs` holds `docs/language.md`, the Basis Library's pages and
the `.def` files to the code. The rest of the prose has no check, and at
this pace it falls behind within days. Found while writing this review:

* This file said "no optimiser" and a Cheney collector a week after both
  had changed.
* `docs/building.md` gives `make check` as about 3 minutes (it is about
  15) and `make test-windows` as 8 (it is about 15).
* `docs/performance.md`:
  * It says "a value is 16 bytes".
  * Its tables predate the word layout and the collector.
* [performance.md](performance.md) estimates 6x to 8x MLton for the
  compiler compiling itself. `docs/performance.md` measures 2.7x.
* [limitations-review.md](limitations-review.md) says `SML90.Interrupt` is
  never raised. It is, since `0dd79e33`.
* [ide.md](ide.md) gives every milestone as not started, while `rune-ide`
  has done M1 to M3 and most of M4.
* [compiler-library.md](compiler-library.md) has M0 waiting for the merge
  of branches that are merged.
* The README of `rune-corpus-sml97` says that Rune does not compile SML/NJ,
  MLton or Poly/ML.

**First step:** when a roadmap is done, retire it into `docs/`, as the
earlier ones were. At each merge that changes a number, re-read
`building.md` and `performance.md`, which quote numbers.

## Done or dropped since 2026-09-24

* **The REPL** (item 4 then): `rune -i` or `rune-repl`, on Linux and
  Windows ([repl.md](../repl.md), PR #39). It has:
  * a line editor, printers, `use` and `:reload`;
  * a debugger and a debug adapter;
  * a Jupyter kernel.
* **An optimiser** (item 2 then, its first half):
  * The middle end's passes run at `-O1` ([ir.md](../ir.md)).
  * Of the ranked list in [performance.md](performance.md), items 1 to 6,
    8, 10 to 17 and 19 are done, and 7 and 18 in part.
  * What is left is item 2.
* **The Basis compiled once, and build files** (item 1 then, in part):
  * Compiled units, a cache, `lib/cache` and build files
    ([units.md](../units.md), [build.md](../build.md)).
  * The two-line program compiles in 0.31 s, down from 1.8 s (*measured
    here*).
  * What is left is item 3.
* **Several errors in one run, with their source** (item 3 then, in part).
  What is left is item 5.
* **Code that Rune did not write** (item 5 then), all compiled by Rune:
  * MLton's compiler, 198,458 lines;
  * HOL4, through `src/boss`;
  * the Basis libraries of MLton, MLKit, SML/NJ (two versions) and Poly/ML,
    about 134,000 lines ([xc2](../../tests/basis/xc2/README.md)).

  CI exists too; its gaps are item 1.
* **The collector and the size of a value** (item 6 then, in part):
  * The collector is generational, with a mark-region collector for
    throughput and a segregated-fits one for low pauses.
  * A value is 8 bytes, with 63-bit `int` and `word`
    ([runtime.md](../runtime.md)).
* **The interrupt** (item 6 then, in part): `Runtime.catchInterrupt` makes
  Ctrl-C raise `SML90.Interrupt`.
* **Libraries** (item 9 then, in part): twelve under `lib/`. They are
  `random`, property testing, `unicode`, `json`, `jsonrpc`, `pretty`,
  `markdown`, `digest`, `terminal`, `zmtp`, `jupyter` and `dap`.
* **Dropped: `Real32`** as a weak point. A value is still a binary64 that
  is rounded to binary32 after every operation, and it behaves as binary32
  (`lib/basis/real32.sml`).
