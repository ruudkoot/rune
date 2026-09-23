# Roadmap: the `Runtime` structure

Written 2026-09-22 on commit `3f3aa91` (branch `basis-runtime`). `Runtime` is
an extension to the basis library: what a program can ask about the machine it
is running on, and what it can tell that machine to do. This roadmap does four
things:

* gives a program the numbers the VM already counts -- instructions, bytes,
  objects, collections, live data -- and a `profile` that reports the
  difference across a call;
* gives it a stack trace worth reading, which means real names for functions
  and source positions in the `.rbc`;
* turns the fork image into a checkpoint a program can write and a VM can
  restore, with `runevm --restore` superseding `--emulate-fork`;
* exposes the three small things that are already there and unreachable:
  forced collection, pointer equality and the version.

Every number below was measured on that commit unless it is marked as an
estimate.

## Specification from the owner

- this is the draft for a Runtime extension to the basis library
- as prerequisites for this i expect
  - source maps in .rbc files for stack traces and debugging
  - checkpoint functionality in the VM
    - this can be exposed as save / restore in Runtime
    - the output format should be architecture independent like the bytecode
    - this should replace the windows fork format if possible
    - i.e. runevm gets a --restore option superceding --emulate-fork
- the Runtime signature should support:
  - save / restore the world
  - force garbage collection
  - get instruction count / memory use / number of allocation / number of gcs stats
  - a higher-order profile function that runs it argument and returns the diff between the stats just named
  - reflect a stack trace as data
  - print the stack trace
  - pointer equality if not exposed elsewhere (or if you have strong objections)
  - the rune version
- test suite for the Runtime library
- examples programs under examples/runtime demonstation the extension

The draft names source maps and checkpointing as prerequisites. They are the
two largest pieces of the work, and nothing in the rest depends on them, so
the order below puts them where their cost falls rather than first: M1 to M3
need no new machinery at all, and the structure exists from M1 on.

## Status

| Milestone | State |
|---|---|
| M0, this roadmap | done (`3f3aa91`): the signature below, four decisions, and every claim of *Where it stands* measured on that commit |
| M1, the structure and the numbers already counted | done: `Runtime.stats` over six primitives that read one field each and allocate nothing, so the five numbers of the heap cannot drift apart while they are read; `runtime_sig.sml`, `runtime.sml` and `seal_runtime.sml`, all three `host = no` in the MANIFEST (D4). It is the same counter `runevm --count` prints: a program that reads it just before it ends reports 27 instructions fewer, which is the printing, in a 2,509-instruction program and in a 272,536-instruction one alike, and the number does not move with `--heap-size`. The suite has 9 checks, which pin what a list cell and a `ref` cost (64 bytes and two objects, 24 and one); they are absent on the four `xc1` hosts, and run on both VMs of Windows, where `--count` still agrees to the byte across all three VMs |
| M2, forced collection, pointer equality and the version | done: `collect` over `vm_gc(vm, 0)`, `same` over the `ptr_eq` the compiler already had for exception identity, and `version`. `scripts/gen-build-files.sh` now writes `vm/version.h` beside `build/config.sml`, so the version is one string: `rune --version`, `runevm --version` and `Runtime.version` all say 0.3.0, where the VM printed 0.2.0 and `man/runevm.1` repeated it, and `check-docs` holds the three manual pages to it. 19 checks. What `same` promises is narrow on purpose: two equal string constants are one object and two lists written separately are two, so only a `ref`, an `array` and an exception constructor are specified. Found on the way: a primitive with no definition in `tests/basis/host/rune-prim.sml` stops the four `xc1` configurations compiling, and `make check` does not run them -- `check-docs` now checks that every primitive of `vm/prims.def` has one, which is Risk 7 turned into a check |
| M3, `profile` | done: the difference of two `stats` around a call, written in SML, nothing in the VM changed. Its own cost is in the answer rather than hidden: `profile (fn () => ())` is 46 instructions, 104 bytes and 1 object -- that object being the first reading's record -- and is the same on every run, so subtracting it from another answer removes it. The checks pin the differences (a list cell costs 64 bytes and two objects more than nothing) rather than the 46, which is codegen's and would break under an unrelated change; a runnable `Example:` pins the one object. An exception from the argument passes through and returns no counters. 26 checks, and `perf-check` reports the same budgets, since no program of `tests/perf` names `Runtime` |
| M4, real names for functions | to do -- M |
| M5, source positions in the bytecode | to do -- L |
| M6, the stack trace | to do -- M |
| M7, a portable image, measured | to do -- L |
| M8, `save`, `restore` and `--restore` | to do -- M |
| M9, the examples and the round-up | to do -- M |

Sizes as in [sml97.md](sml97.md): S about a day, M a few days, L a week or
more, XL several weeks.

## Where it stands

### What the VM already counts

Every statistic the draft asks for is already kept, unconditionally, in the
`VM` struct. Nothing has to be measured that is not measured now; what is
missing is a way to read it.

| Number | Field | Kept at |
|---|---|---|
| instructions executed | `instructions` (`vm/vm.h:125`) | `vm/interp.c:210`, in the dispatch loop, with no `#ifdef` |
| bytes allocated | `bytes_allocated` (`vm/vm.h:123`) | `vm/heap.c:38` |
| objects allocated | `objects_allocated` (`vm/vm.h:124`) | `vm/heap.c:39` |
| collections | `gc_count` (`vm/vm.h:120`) | `vm/heap.c:115` |
| live data | `heap_used` (`vm/vm.h:119`) | `vm/heap.c:113` |
| a semispace | `heap_size` (`vm/vm.h:118`) | `vm/heap.c:114` |
| collector time | `gc_user_us`, `gc_sys_us` (`vm/vm.h:121-122`) | `vm/heap.c`, around every collection |

The last pair is the only one a program can reach: `time_gc_user` and
`time_gc_sys` (`vm/prims.def:168-169`) are read by `Timer.checkGCTime`
(`lib/basis/timer.sml:14-15`). That chain -- a line of `vm/prims.def`, a
`p_` function in `vm/prims.c`, a `_prim` binding in `lib/basis` and a
definition in `tests/basis/host/rune-prim.sml` -- is the worked example every
primitive of M1 and M2 copies.

`runevm --stats` and `runevm --count` print these at exit (`vm/main.c:46-58`).
`--count` is deliberately reproducible: it depends on the program and its
input alone, which is what makes it a performance budget (`make perf-check`)
and how the Windows runner checks that all three VMs lay out a value the same
way.

Two more things are there and unreachable:

* **Forcing a collection** is `vm_gc(vm, 0)` (`vm/heap.c:119`). There is no
  primitive for it.
* **Pointer equality** is a primitive already, `ptr_eq` (`vm/prims.def:11`,
  `vm/prims.c:85`). Its only caller is the compiler itself, which tests the
  identity of an exception constructor with it (`src/core/matchcomp.sml:71`).
  No structure of `lib/basis` mentions it.

### What a stack trace would have to say

The frame stack is walkable, and the collector already walks it: `Frame` is
`{func, ret_pc, base, closure}` (`vm/vm.h:80-85`), and `vm/heap.c:93-95`
iterates `frames[0..fp]` to find the roots. `Function` carries `code_end`, so
a pc names its function without a search. A backtrace is that loop again.

Nothing walks it. When an exception reaches the top, `vm_raise`
(`vm/interp.c:136`) prints `runevm: uncaught exception Name payload` and exits
**with the whole frame stack intact and unexamined**. The only code that names
a function at all is `vm_fatal` (`vm/interp.c:5`), and only the innermost one.

What it would print today is the trouble:

* **Every closure is called `fn`.** `src/backend/codegen.sml:218` names a
  function `"fn" ^ Int.toString s` when it is recursive and `"fn"` when it is
  not, so a trace would read `fn41733`. Only `<toplevel>` means anything.
* **There is no source position anywhere in a `.rbc`.** The abstract syntax
  has spans (`Source.span = {file, start, stop}`, `src/util/source.sml:5`),
  but `Lambda.lexp` has no span field (`src/core/lambda.sml:12-40`), so
  `src/core/translate.sml` drops them; the code generator's items carry none
  either, and the only per-function metadata the file holds is
  `code_offset, nlocals, name` (`src/backend/emit.sml:62`).
* **The file format has no room to be extended.** Its sections are magic,
  version, constants, globals, functions and code (`docs/bytecode.md:11-24`),
  with no length-delimited tail. A debug section is a version bump:
  `src/backend/emit.sml:10` and `vm/loader.c:66-67`, which is `1` on both
  sides today.

### The image, and what it is not

`vm/image.c` already writes the whole VM to a stream and reads it back --
the heap, the stacks, the frames, the handlers, the globals, the program, the
open files, the rounding mode and every counter -- and `heap_relocate`
(`vm/heap.c:157`) moves the heap's pointers to wherever the second VM put its
own, validating each object as it goes. `runevm --resume TOKEN` is the reading
end (`vm/main.c:94-105`), and it re-enters `vm_loop` (`vm/interp.c:201`),
which is exactly the re-entry a restore wants. On Windows this is how
`Posix.Process.fork` works at all, and `runevm --emulate-fork` takes the same
path on Linux, where `tests/lang/rt.fork_image` runs it under ASan and
`make test-stress`.

It is not, however, what the draft asks for, in two ways.

* **It is fork-only.** `vm_resume` ends by popping the argument `posix_fork`
  left on the stack and pushing `mk_int 0`, so that the fork returns 0 in the
  child, and it refuses an image whose stack is empty with "the image was not
  made by fork" (`vm/image.c:278-282`). There is no record in the image of
  what the resumed world should do next.
* **It is not architecture-independent.** `PUT(s, x)` is
  `fwrite(&x, sizeof x)` (`vm/image.c:27-30`): native width, native
  endianness, native padding, raw `Value`, `Obj` and `Frame` structs, and the
  heap written with its absolute base address (`vm/image.c:75-79`). A guard
  word of four `sizeof`s (`vm/image.c:41`) makes a mismatched image a clean
  refusal -- "not an image of this runevm", `vm/image.c:170-172` -- rather
  than a crash, so what is missing is portability, not safety.

A fork costs 12 ms plus about 3 ms for each MB of live heap, measured on both
Windows VMs when M12 of the Windows roadmap was built.

### The version, which disagrees with itself

`scripts/gen-build-files.sh:55` writes `build/config.sml` with
`val version = "0.3.0"`, which is what `rune --version` prints. `vm/main.c:89`
prints `runevm 0.2.0`, and `man/runevm.1` repeats the stale one. Neither
reaches a compiled program: `build/config.sml` belongs to the compiler's own
build and is not in `lib/basis/MANIFEST`.

### What an extension structure costs

`INet6Sock` (`f227fd2`) is the only structure of the library that is not in
the specification, and it is the template. What `Runtime` needs:

* `lib/basis/runtime_sig.sml`, `lib/basis/runtime.sml` and
  `lib/basis/seal_runtime.sml`, with three lines in `lib/basis/MANIFEST`
  beside `inet6sock`'s (`:144`, `:145`, `:282`). The signature file is
  **not** `sig_runtime.sml`: `scripts/gen-basis-sigs.sh --check` fails for a
  `lib/basis/sig_*.sml` with no transcription under `tests/basis/spec-sigs`,
  and an extension must not have one.
* `Status: extension` on the signature and `Implements: RUNTIME` on the
  structure. `tests/basis/check-claims.sh` requires the first of a signature
  with no transcription, and treats a signature that nothing implements as an
  error -- so `RUNTIME` and `structure Runtime` land in one commit, as
  `WINDOWS` did.
* A check in `tests/basis/runtime.sml` labelled `Runtime.<member>/...` for
  every `val` of the signature. `src/doc/docsite.sml:719` makes a member
  without one a hard error of `make docs` and `make check-docs`, so the suite
  is written with the structure and not after it.
* A definition in `tests/basis/host/rune-prim.sml` for every new primitive.
  That file is ascribed `: RUNE_PRIM`, which is generated from
  `vm/prims.def`, so a primitive with no definition stops the `xc1`
  configurations compiling. The ones no host can answer follow the Windows
  block at the end of that file: `unsupported ~1`, which sets `ENOSYS`.
* A `basis.runtime` row in `docs/language.md` with a test
  `tests/lang/basis.runtime.sml`, an entry in `docs/bytecode.md` for each
  primitive, and `make docs` re-run and committed.

`examples/runtime` is new ground. `examples/` is flat today, and the only
thing that reads it is `scripts/check-cross.sh:98`, whose glob
`examples/*.sml` does not descend, so a subdirectory needs a line there --
and the five builds must then agree byte for byte on those programs too.

## The signature

The whole of `RUNTIME`, so that the milestones can name members instead of
describing them again. `int` is 64 bits on every Rune VM, whatever the pointer
width, so the counters need no `IntInf`.

```sml
signature RUNTIME =
  sig
    type stats = { instructions : int, bytes : int, objects : int,
                   collections : int, live : int, heapSize : int }
    val stats : unit -> stats                  (* M1 *)
    val profile : (unit -> 'a) -> 'a * stats   (* M3 *)
    val collect : unit -> unit                 (* M2 *)

    type frame = { function : string, file : string, line : int, column : int }
    val trace : unit -> frame list             (* M6 *)
    val printTrace : TextIO.outstream -> unit  (* M6 *)

    val same : 'a * 'a -> bool                 (* M2 *)
    val version : string                       (* M2 *)

    datatype world = Saved | Restored
    val save : string -> world                 (* M8 *)
  end
```

`stats` is the whole of the numbers rather than one function each, so that a
reader gets a consistent set: two calls a moment apart differ, and `profile`
subtracts one record from another. `live` and `heapSize` are the answer to
"memory use": the bytes the last collection kept and the size of a semispace.

## Design decisions

### D1. One image format, or two (open: the owner picks, on M7's numbers)

The draft asks that the checkpoint be architecture-independent like the
bytecode and that it replace the fork format. A portable encoding makes every
`fork` on Windows pay for a portability that the fork path cannot use: both
ends of a fork are the same binary by construction.

**M7 builds the portable encoder and measures it**, forking 20 times with 0,
16 and 64 MB live on `bin/runevm`, `bin/runevm.exe` and `bin/runevm32.exe`,
against the 12 ms + 3 ms/MB the native one costs. The owner then picks:

* **A. One format.** `vm/image.c` writes portably and both fork and
  `save` use it. Simplest, and `--restore` genuinely supersedes
  `--emulate-fork`.
* **B. Two.** The native encoder stays for fork, the portable one is written
  only by `save`. One set of structures, two writers and two readers.

The threshold to propose: if the portable encoder costs less than 25% more
per MB, take A. The roadmap assumes A until the numbers say otherwise, and
M8's work is the same either way.

### D2. `restore` is a command line, not a function

A restore replaces the world it runs in, so there is nothing for it to return
to. It is `runevm --restore FILE`, which is what `--resume` already is
(`vm/main.c:94-105`). An in-process `restore : string -> 'a` that never
returns normally is implementable -- it is `--resume` from inside the loop --
but it throws away the stacks of a call that is still running, and no use for
it has come up. Left out; M8 can add it if one does.

### D3. `save` returns `Saved` or `Restored`

The image-writing call returns twice, as `fork` does: once in the process that
wrote it, and once in whatever VM restores it. `fork` says this with 0 and a
pid, which is POSIX's idiom and not SML's. `datatype world = Saved | Restored`
says it in the language's own terms and cannot be got the wrong way round.

### D4. `runtime.sml` is `host = no` in the MANIFEST

Nothing a host's SML system can do stands in for reading Rune's instruction
counter or walking Rune's frames. Making the file absent on the hosts
(`host = no`, as `epilogue.sml` is) makes the suite report the test as N/A
there rather than run it against stubs that all raise. The primitives still
need definitions in `tests/basis/host/rune-prim.sml`, because that file is
ascribed to a signature generated from `vm/prims.def`, but they are
`unsupported ~1` and nothing calls them.

## Constraints for all items

* Each milestone is one or more commits, and each commit leaves `make check`
  green. A change to the VM also passes `make vm-asan && sh
  tests/run-tests.sh --vm bin/runevm-asan` and `make test-stress`.
* A milestone carries its own tests and documentation. A member of `RUNTIME`
  arrives with a check labelled `Runtime.<member>/...` in `tests/basis`,
  because `src/doc/docsite.sml:719` fails `make check-docs` without one, and
  with its doc comment, because `RUNTIME` joins `lib/basis/DOCUMENTED` at M9
  and the ratchet then makes a missing comment an error.
* A new primitive goes through `vm/prims.def` and `docs/bytecode.md`, is
  implemented as `p_<name>` in `vm/prims.c`, and is written on the hosts in
  `tests/basis/host/rune-prim.sml` for the `xc1` configurations.
* **`runevm --count` stays reproducible.** It is a performance budget
  (`make perf-check`) and the check that all three VMs lay out a value alike.
  A milestone may not change what an existing program counts; a program that
  calls `Runtime` may count more, which is why the perf programs call none.
* Nothing absolute enters a `.rbc`. The file names M5 records are the ones
  given on the command line, so that the five builds of `make check-cross`
  still emit identical bytecode from any directory.
* After a library change run `make matrix-quick`; after a change to the VM
  core, `vm/sys.h` or a system layer, `make windows` and `make test-windows`,
  since `make check` never compiles `vm/sys_win.c`.
* An `.expected` file is written by hand or reviewed line by line. M6 changes
  what an uncaught exception prints, and every file that changes is read.

## Milestones

M1 to M3 need nothing that does not exist, and each is about a day. M4 to M6
are the stack trace, in the order name, position, walk. M7 and M8 are the
checkpoint. M9 closes the documentation and the examples.

### M1. The structure, and the numbers already counted -- S

* **The library files.** `lib/basis/runtime_sig.sml` with `RUNTIME` as far as
  `stats` (`Area: The runtime`, `Status: extension`, and a `Deviation:` note
  saying it is not in the specification, as `INET6_SOCK` has). The area is a
  new one -- they are free text, gathered in MANIFEST order
  (`src/doc/docsite.sml:150-161`) -- so `docs/generated/basis/README.md`
  gains a section for it;
  `lib/basis/runtime.sml` with `RuneRuntime` and
  `(* Implements: RUNTIME *) structure Runtime = RuneRuntime`;
  `lib/basis/seal_runtime.sml`; three lines of `lib/basis/MANIFEST`, the
  implementation `demand` and `host = no` (D4).
* **Six primitives** over the counters of *Where it stands*: `rt_instructions`,
  `rt_bytes`, `rt_objects`, `rt_collections`, `rt_live`, `rt_heap_size`, each
  `1  unit -> int`, each a one-line `p_` function in `vm/prims.c` returning
  `mk_int` of its field, appended to `vm/prims.def` (numbers are positions, so
  new ones go at the end) and described in `docs/bytecode.md`.
  `tests/basis/host/rune-prim.sml` gets six `unsupported ~1`.
* **`stats`** reads the six in one call and returns the record.
* **The tests.** `tests/basis/runtime.sml` with a check per member,
  `tests/basis/runtime_sig.sml` on the model of `tests/basis/inet6sock_sig.sml`
  (no `SPEC_` ascription), `tests/lang/basis.runtime.sml` with a
  hand-written `.expected`, and a `basis.runtime` row in `docs/language.md`.

*Leaves verifiable:* a program prints `#instructions (Runtime.stats ())` just
before it ends, and the number agrees with what `runevm --count` prints at
exit for the same run, to the instruction.

### M2. Forced collection, pointer equality and the version -- S

* **`collect`** is a primitive `rt_collect` over `vm_gc(vm, 0)`
  (`vm/heap.c:119`). It is the one call in the structure that must be written
  to the GC discipline of `docs/architecture.md`: it collects, so it may hold
  no heap pointer in a C local.
* **`same`** is a `_prim` binding of the existing `ptr_eq`
  (`vm/prims.def:11`). No new primitive, no C. Its doc comment says what it
  is for -- an identity test where `=` is not available or not wanted -- and
  what it is not: two structurally equal values may or may not be the same,
  and a collection does not change the answer, because the collector
  maintains identity (`docs/runtime.md:50-52`).
* **`version`** ends the disagreement. `scripts/gen-build-files.sh` writes a
  `vm/version.h` beside `build/config.sml` from the one string it already
  has, `vm/main.c:89` prints that instead of its literal `0.2.0`, a primitive
  `rt_version` returns it, and `man/runevm.1`'s header is corrected.

*Leaves verifiable:* `rune --version`, `runevm --version` and
`Runtime.version` print the same string, checked by a test; and a `ref`
compared with `Runtime.same` before and after `Runtime.collect` is still the
same as itself and still not the same as an equal one.

### M3. `profile` -- S

* **The function** runs its argument, subtracts the `stats` taken before from
  the `stats` taken after, and returns the result beside the value. It is
  written in SML in `lib/basis/runtime.sml`; nothing in the VM changes.
* **Its own cost is measured and documented.** The calls to the six
  primitives are themselves instructions and the record is itself an
  allocation, so `profile (fn () => ())` does not report zero. Measure what it
  does report, state it in the doc comment as the overhead included in every
  answer, and pin it with a check.
* **Exceptions.** If the argument raises, the exception passes through and no
  statistics are returned: `profile` is not a `handle`. Said in the doc
  comment and checked.

*Leaves verifiable:* `profile (fn () => ())` reports the documented constant
on every VM, and `make perf-check` reports the same budgets as before, since
no program of `tests/perf` calls `Runtime`.

### M4. Real names for functions -- M

The `.rbc` already has a name for every function (`src/backend/emit.sml:62`)
and nothing worth printing in it. No format change; only what is written
there.

* **Name a closure for what binds it.** `src/backend/codegen.sml:218` is given
  the name in scope at the point the function is translated, qualified where
  the structure is known (`Array.sub`, not `sub`), and keeps `fn` with the
  stamp only for a function that truly has no name. This means carrying the
  binding's name from `src/core/translate.sml`, which knows it.
* **`<toplevel>` stays** what it is (`src/backend/codegen.sml:258`).
* **What reads them.** `runevm --disasm` and `vm_fatal`'s message
  (`vm/interp.c:5`) improve for free. `tests/vm` gains a case fixing the
  message of a fatal error in a named function.

*Leaves verifiable:* `runevm --disasm` of `examples/nqueens.rbc` names
`place` and `solve`; no program of `tests/lang` disassembles to a function
called `fn` followed by a number, except where SML gives it no name; the five
builds of `make check-cross` still agree byte for byte.

### M5. Source positions in the bytecode -- L

The largest milestone, and the one with uses beyond this roadmap: it is what
a debugger would need.

* **A span on every `lexp`.** `src/core/lambda.sml:12-40` gains a span, or a
  `Mark of Source.span * lexp` node -- whichever costs the optimiser less --
  and `src/core/translate.sml` fills it from the abstract syntax, which has
  the spans already (`src/frontend/ast.sml`).
* **Through the code generator.** `src/backend/codegen.sml` carries the
  current span as it emits, so that every instruction has a position.
* **A section in the file.** `src/backend/emit.sml` writes, per function, a
  line table delta-encoded over pc and position, as DWARF's line program is,
  and a table of file names shared by the whole file. The version becomes `2`
  in `src/backend/emit.sml:10` and `vm/loader.c:66`, and
  `docs/bytecode.md:11-24` describes the new sections.
* **The loader checks it** as it checks everything else: every offset, index
  and length validated before anything runs, a table that does not parse
  refused with status 2. `tests/vm` gains crafted files for a truncated
  table, a pc outside its function, a file index out of range and a delta
  that overflows.
* **Paths are as given.** The file name stored is the one on the command
  line, never made absolute, so `make check-cross` still gets identical
  bytecode from five builds and any directory.
* **`--disasm` prints positions**, which is how the table is read by hand.

*Leaves verifiable:* for every program of `tests/lang`, every pc of every
function maps to a position inside the file it was compiled from -- a check
over `--disasm` output; each of the crafted `tests/vm` files is refused with a
message and status 2; the five builds still agree byte for byte; and the
growth of `tests/perf/compile-hello.budget` is recorded with the milestone.

### M6. The stack trace -- M

* **The walk.** A function in the VM that iterates `frames[fp..0]` as the
  collector does (`vm/heap.c:93-95`), taking the name from
  `prog.funcs[frames[i].func].name` and the position from M5's table at
  `frames[i].ret_pc - 1` for a caller and at `vm->pc` for the innermost
  frame.
* **As data.** A primitive `rt_trace` builds the list of records that
  `Runtime.trace` returns. It allocates, so it is written to the GC
  discipline.
* **As text.** `Runtime.printTrace` formats that list to an outstream.
* **On an uncaught exception.** `vm_raise` (`vm/interp.c:136`) prints the
  trace under its message before it exits, which is the change a user of Rune
  will actually notice. `vm_fatal` prints it too, in place of its one
  function.
* **Tail calls are invisible**, because `OP_TAILCALL` overwrites the frame in
  place (`vm/interp.c:318-321`). This is true of every language that
  guarantees tail calls; the doc comment of `trace` says so rather than
  leaving a reader to wonder where a frame went.
* **The `.expected` churn.** Every test whose program ends in an uncaught
  exception now prints more. Each changed file is read line by line, never
  `--update`d blindly.

*Leaves verifiable:* `tests/lang/rt.trace` -- a program that raises three
calls deep -- prints the three frames with their names and lines, matching a
hand-written `.expected` on all three VMs.

### M7. A portable image, measured -- L

* **The encoding.** `vm/image.c` stops writing structs. Every field becomes a
  tagged, fixed-width, little-endian item, as `docs/bytecode.md:11` describes
  for the bytecode: `u8`, `u32`, `i64`, and a `Value` written as its tag and
  its payload rather than its 16 bytes. The heap is written with offsets
  from its base instead of `uintptr_t base` (`vm/image.c:75-79`), which is
  what `heap_relocate` (`vm/heap.c:157`) already expects to fix up. The
  `sizeof` guard (`vm/image.c:41`) goes, and with it the refusal at `:170`.
* **The reader validates**, since an image is now something that can come
  from elsewhere: every kind, length, index and offset checked before it is
  used, as the bytecode loader does. `heap_relocate` already refuses an
  unsound heap; the stacks, frames, handlers and globals get the same
  treatment.
* **The benchmark that settles D1.** 20 forks with 0, 16 and 64 MB live, on
  `bin/runevm`, `bin/runevm.exe` and `bin/runevm32.exe`, native encoder
  against portable. The numbers go into *Risks* as a `*Measured*` line and
  the owner picks A or B.

*Leaves verifiable:* an image written by `bin/runevm` is resumed by
`bin/runevm32.exe` and the program runs to the same end -- 64-bit to 32-bit,
which the old format refused by construction; and `rt.fork_image` still passes
under ASan and `make test-stress`.

### M8. `save`, `restore` and `--restore` -- M

* **A recorded re-entry.** The image says what the resumed world should do,
  in place of `vm_resume`'s hard-wired "pop one, push 0"
  (`vm/image.c:278-282`): a small tag saying *resume a fork* or *resume a
  save*, so that both work and neither is the other's special case.
* **`save`** writes the image to a named file and returns `Saved`; a VM
  started on that file resumes inside the same call, which returns `Restored`
  (D3). Everything the fork path already carries -- open files, sockets,
  directory streams, the rounding mode -- is carried here, because it is the
  same image.
* **`runevm --restore FILE`** supersedes `--emulate-fork`, as the draft asks.
  `--emulate-fork` is what `tests/lang/rt.fork_image.vmargs` passes and what
  `make check` uses to test the fork path on Linux; it stays as the name of
  *that* behaviour, with `--restore` as the general one, and
  `docs/bytecode.md` and `docs/runtime.md:171-177` say which is which.
* **What a restore cannot do** is say so plainly: an image belongs to the
  program that wrote it, and a VM of another bytecode version refuses it, as
  the loader refuses a `.rbc` of another version.

*Leaves verifiable:* a program writes a checkpoint, exits, and
`runevm --restore` finishes it in another process minutes later with its open
files intact -- a test under `tests/lang` -- while `rt.fork_image` still
passes under ASan and `make test-stress`, and `make test-windows` still forks
on both VMs.

### M9. The examples and the round-up -- M

* **`examples/runtime`**, with a program for each part of the structure: the
  statistics of a run, `profile` around a known loop, a trace printed from a
  handler, and a checkpoint written and restored. `scripts/check-cross.sh:98`
  learns to descend into it, which puts those programs under the five-build
  identity check as well.
* **The documentation.** `RUNTIME` joins `lib/basis/DOCUMENTED`, which turns
  its doc-comment warnings into errors; `docs/basis-compat.md` gains a
  paragraph beside `INet6Sock`'s (`:209-217`) saying what `Runtime` is and
  that no other system has it; `README.md` lists it; and `docs/runtime.md`
  gains a section pointing at the structure, since that page is where a
  reader looking for this already is.
* **The round-up.** `make docs` re-run and committed, `make matrix-quick`,
  and the *Status* table above filled in.

*Leaves verifiable:* `make check` and `make matrix-quick` green; every member
of `RUNTIME` has a check that pins it and a doc comment that survives the
ratchet; and every program of `examples/runtime` compiles to identical
bytecode under all five builds.

## Risks

1. **`--count` is a budget.** Instruction counts are reproducible by design
   and `make perf-check` compares against them.
   * *Mitigation:* the counters already increment unconditionally, so M1 to
     M3 add nothing to a program that does not call `Runtime`, and no program
     of `tests/perf` does. M4 and M5 change names and add a section, neither
     of which is executed. Re-run `make perf-check` at every milestone.
2. **The line table makes every `.rbc` bigger.**
   * `tests/perf/compile-hello.budget` pins the size of a compile.
   * *Mitigation:* delta encoding, one shared file-name table, positions only
     where they change. M5 records the growth and the budget is bumped in
     that commit with the number in its message.
   * *Measured:* to be filled in at M5.
3. **A path in the bytecode would break two things at once.** An absolute
   path would make the five builds of `make check-cross` disagree and would
   break the rule that nothing absolute is baked into a `.rbc`.
   * *Mitigation:* store the name exactly as given on the command line; M5's
     verification runs the five builds from different directories.
4. **M6 changes what a failing program prints**, so `.expected` files change
   in a way `--update` would happily paper over.
   * *Mitigation:* M6 lists the files it changes and each is read line by
     line, as `AGENTS.md` requires.
5. **A portable image may make every fork slower**, and on Windows `fork` has
   no alternative.
   * *Mitigation:* D1 is not decided in advance. M7 measures both encoders at
     three sizes on three VMs and the owner picks; B keeps the fast path if
     the cost is real.
   * *Measured:* to be filled in at M7.
6. **Tail calls do not appear in a trace**, which will look like a missing
   frame to someone who does not know why.
   * *Mitigation:* the doc comment of `trace` says it, and
     `tests/lang/rt.trace` includes a tail call so that the behaviour is
     pinned rather than accidental.
7. **Every new primitive must be answered on the hosts.**
   `tests/basis/host/rune-prim.sml` is ascribed to a signature generated from
   `vm/prims.def`, so a forgotten definition stops four `xc1` configurations
   compiling -- and `make check` does not run them.
   * *Mitigation:* the definition is part of the same commit as the
     primitive, and `make matrix-quick` runs at every milestone that adds one.
8. **`collect` and `trace` allocate or collect inside a primitive**, which is
   where the GC discipline is easiest to get wrong.
   * *Mitigation:* `make test-stress` collects at nearly every allocation and
     is run for every VM change; it is what this class of bug is for.

## Out of scope

* **A debugger.** M5 is what one would be built on -- positions for every pc,
  and names worth printing -- but breakpoints, stepping and inspecting a live
  frame are a project of their own.
* **A sampling or per-function profiler.** `profile` is the difference of
  whole-VM counters across a call, which is what the draft asks for. Counting
  per function means a cost on every call.
* **Signal handling.** `SML90.Interrupt` is never raised because the VM
  handles no signal, and fixing that means the interpreter checking a flag at
  safe points -- a cost on every loop, for an exception the specification
  itself calls obsolete (`docs/plans/limitations-review.md`).
* **Heap introspection.** Walking the live objects, or asking what retains
  what, needs the collector to expose a traversal it does not have.
* **Restoring an image into a different program.** An image carries its
  program; resuming one under other bytecode is refused, as a `.rbc` of
  another version is.
* **Exposing the rounding mode, the heap size or `--gc-stress`** as settings a
  program can change. `Runtime` reports the machine and collects on demand;
  the command line configures it.

## Verification

* Each milestone's *Leaves verifiable* line holds.
* `make check` stays green at every commit, with `make vm-asan` and
  `make test-stress` for the milestones that touch `vm/`, and
  `make matrix-quick` for those that touch `lib/basis`.
* `make windows` and `make test-windows` pass on both VMs for M5, M7 and M8,
  which change the file format, the image and the fork path.
* `make perf-check` reports unchanged budgets, except at M5, where the change
  is recorded with its number.
* At the end, `Runtime` has a page in `docs/generated/basis` with every member
  documented and pinned by a check, `examples/runtime` compiles identically
  under five builds, and `runevm --restore` has replaced `--emulate-fork`
  everywhere but in the test that exists to exercise the fork path.
