# Roadmap: native code (codegen)

Written 2026-09-23 on commit `e099de5`, on branch `codegen`. The tool this
roadmap describes takes an `.rbc` and writes a Linux x86-64 executable. The
translation is straightforward: each bytecode instruction becomes the machine
code that does what `vm/interp.c` does for it, and the result is linked
against the VM's runtime. The roadmap does five things:

* It states the facts a translator has to respect. Some of them come from
  reading the code. The rest come from a static analysis of 422 compiled
  programs, listed under *What the corpus does*.
* It takes fourteen decisions, D1 to D14, preceded by D0, which defines
  what "straightforward, no optimisation" allows. The owner took the open
  ones of D1 to D12 on 2026-09-23; D13 and D14, added with M10 to M15, are
  open.
* It orders the work in fifteen milestones. M1 to M8 give native programs
  that pass the existing suites with the same instruction counts as runevm,
  plus debug information and a place in the performance comparison; M10 to
  M15, added on 2026-09-24, make them faster, the biggest gain for the least
  work first.
* It sets out the options for save and restore, as the draft asks. That work
  is M9, which is optional.
* It says where each line of the draft is answered.

Every number below was measured on that commit or is marked as an estimate.
The corpus is the `.rbc` files that `make check` last compiled: the compiler
and `runedoc`, the 148 programs of `tests/lang`, the 220 of the Basis Library
suite, the 11 of `tests/perf` and the 41 runnable examples.

## Specification from the owner

- this is a draft for a native code generation tool
- the tool should take an .rbc file and generate native linux executable in x64
  - it should convert the rbc source map into native debugging data
  - windows and non-x64 platforms are out-of-scope for now but should be able to be supported in the future
- it should reuse the compilers code and the native code should be a straightforward translation of rune bytecode into x64 machine code (i.e. not an interpreted of bytecode presenting as a linux executable nor do any optimizations of the bytecode while translating into x64 machine code)
- the x64 code should be linked against the heap, image, sys_posix from the vm to reuse that as the runtime system.
- new test suite for the code generation tool itself and running the native code should be part of the existing test suites.
- existing (real time) performance test should also compare rune native code programs against runevm and other compilers
- native code should support most of the Runtime basis libraries functionality:
  - instruction couting (bytecode equivalent) and heap statistics
  - stack traces
  - save / restore
    - this may be (very) tricky so research some implemenation strategies and present them as options for a final optional milestone

The owner added the following while this roadmap was being written
(2026-09-23):

* Some primitives should be inlined, arithmetic for example (D12).
* A small shell script that turns an `.sml` into an executable is welcome
  now, for trying things out (M3).
* lldb, `llvm-dwarfdump` and perf are installed now (see *Toolchain*).

The owner's decisions on the roadmap (2026-09-23):

* **D3:** B. A may be tried later.
* **D8:** as proposed, to be revisited later (see *To revisit*).
* **D11:** option 1, and `runeopt --from-image` as well. The other options
  may be tried later. `Runtime.restore` raises `OS.SysErr` for now; a
  compiler or an interpreter offered as a service may take its place later.
* **The tool's name:** `runeopt`.

## Status

| Milestone | State |
|---|---|
| M0, this roadmap | done (`fe759b8`): every claim of *Where we are* measured on `e099de5`, twelve decisions, nine milestones |
| The owner's decisions | taken on 2026-09-23: D3 = B, D8 as proposed (to revisit), D11 = option 1 with `--from-image` and `OS.SysErr` from `Runtime.restore` for another program's image, the name `runeopt`; on 2026-09-24: D13 = B (a fused opcode in the compiler), D14 = C (`--heap-fill`, half by default), and M10 to M15 to be done, each with an analysis of what it gained and what it cost in code |
| M1, the runtime as a library | done: `vm/runtime.c` has what a VM does besides dispatching (frames, handlers, raising, the trace of a failure, equality, `vm_init`, `vm_start`, `vm_exit`, `vm_release`), taken out of `interp.c` and `main.c`; `load_program_mem` loads an `.rbc` from memory; `build/librune.a` is the runtime for this machine and `bin/runevm` links it. The other VMs compile the same list, `RT_SRCS`, in their one `cc` call, which removes the duplicated lists of sources. Nothing a program sees changed: `make check`, `make test-windows` and `make test-portability` pass, and `--count` agrees with the VM before |
| M2, the `.rbc` reader, the validator and the tool | done: `runeopt --check`, `--disasm` and `--facts` (`Rbc`, `RbcCheck`, `RbcDisasm`, `OptMain` in `src/opt`), built by all five, whose bytecode `check-cross` compares and whose output `scripts/check-opt-cross.sh` compares. `tests/opt`: 16 files refused (8 by the loader's checks, with its messages, 8 by D0's) and `--check` and `--disasm` over every program the suites compiled (368). The check finds exactly the facts of *What the corpus does* (437,885 functions, 12,639,613 instructions, 235,894 unreachable). Two things `--disasm` parity found: C's `%.*s` ends a string constant at its first NUL, and awk loses the sign of `-0`. What the cross-check found: SML/NJ 110.99.9 in 32 bits compiles `c - x`, where the literal `c` is its `Int.maxInt`, into code that overflows whatever `x` is; the reader takes that bound from a string. The drift listed above is fixed |
| M3, every instruction translated | done: the templates of all 34 opcodes (`src/opt/x64.sml`), the glue (`vm/native.c`), the layout the code names (`build/rune-offsets.s`, from `vm/native_offsets.c`), `runeopt prog.rbc -o prog` with `-S` and `--options`, and `scripts/opt.sh`. `tests/opt/every-opcode.rasm`, assembled by `tests/opt/rbcasm.awk`, runs every opcode, `HALT` and `JUMPIF` among them; it, `hello`, fib, nqueens and tak print what they print under `runevm`, with the same counts, and so do all the programs of `tests/perf`. The compiler as native code compiles itself to `bin/rune.rbc`, byte for byte: 969 million instructions in 21 s, on a machine with a load of 20. Measured on the compiler: 20.5 MB of assembly, translated in 1.4 s by the MLton build of `runeopt` (the self-hosted one translates `runeopt.rbc`, 357 KB, in 6 s), assembled and linked in 5.2 s, 5.6 MB of machine code, about 51 bytes per instruction where D5 estimated 20 to 40. A native program's `Runtime.restore` raises `OS.SysErr` (`ENOSYS`) |
| M4, the suites, run natively | done: `bin/runevm-opt` (`scripts/runevm-opt.sh`) is a VM for the runners: it translates the bytecode with `runeopt`, keeps each translation by the checksum of the bytecode, gives the program the options of `runevm` in `RUNEVM_OPTIONS` and its name in `RUNEVM_NAME`, and hands `--restore` and the like to `runevm`. `make test-native`, part of `make check`: `tests/lang` natively (205 of 206; `rt.fork_image` waits for M9, `tests/opt-skip.txt`); `--count` equal to `runevm`'s for all 146 programs (`tests/opt/run-counts.sh`); the Basis Library suite in the configuration `rune:opt`, all 137,276 checks, reusing the bytecode `test-basis` compiled where its sources are the same, which takes the run from 163 s to 19 s; and the compiler as native code compiling itself to `bin/rune.rbc` (`tests/opt/run-bootstrap.sh`). `make test-native-stress` (a collection before every 101st allocation, the Basis Library suite every 1009th) and `make test-native-asan` (the runtime built with ASan and UBSan) pass too, and there is a doctor scope `native`. A native program's `Runtime.save` writes an image `runevm --restore` carries on (the three `.restore` tests). Found on the way: the program saw `RUNEVM_OPTIONS` in its environment (`basis.posix_process` counted more), and bash, whose `exec -a` would set `argv[0]`, takes the variable `_` out of the environment, so the wrapper is sh and the name comes in `RUNEVM_NAME`; LeakSanitizer found the copy of that name. `tests/vm` is not run natively: it tests the loader and the command line of `runevm`, and `tests/opt` has the loader's refusals for `runeopt` |
| M5, inlined primitives | done: 56 primitives are inline (`fastPrim` in `src/opt/x64.sml`, `runeopt --inlined`): the arithmetic and comparisons of ints, words, reals and chars, the conversions between them, `=` on two values that are not pointers or reals, `!` and `:=`, and the length and elements of strings, vectors and arrays; anything unusual calls the primitive. Chosen by what the programs of `tests/perf` and the compiler compiling `hello` execute: 8.3 million primitive calls, 9.1% of their 91 million instructions, of which `poly_eq` is 48.6%, `int_add` 16.0%, `int_sub` 5.9%, `int_lt` and `int_mod` 4.4% each; the 56 are 99.1% of the calls. `tests/opt/prims.sml` runs each on its edge cases, 3,321 lines of output that are the same natively and on `runevm`, with the same counts, and `tests/opt` fails if it stops using one of them. `make check`, `make test-native-stress` and `make test-native-asan` pass. The timings before and after are M7's |
| M6, debug information, checked | done: every function has CFI (the frame of `rune_enter`, which the code never changes), so a debugger unwinds from an SML function to `main`, and a position from its first byte; `runeopt --lines` prints the table of a `.rbc`. `tests/opt/run-debug.sh`, part of `make test-native`: for the compiler and every program of `tests/lang`, the line table as `llvm-dwarfdump` reads it (file, line, column) and as `readelf` decodes it is the position of every instruction that has code, in order, and `addr2line` gives every function at its symbol its first line; gdb and lldb stop at a line of `examples/nqueens.sml`, and lldb names the function (`place#235`). What it found is under D7 |
| M7, performance | done: `make perf` with `rune:opt` beside `rune` and the hosts, in [basis-compat.md](../basis-compat.md): natively the programs of `tests/perf` run 1.8 to 4.0 times faster than on `runevm` (`fib` 5.6 ms against 10.8, `tak` 3.7 against 10.5, `real_nbody` 2.5 against 10.0), still 10 to 40 times slower than the hosts; the compiler compiles itself in 5.5 s against 10.2. The inlining of M5 gains 3% (`tak`) to 33% (`word_bits`), measured against the `runeopt` of M4. A profile of the native bootstrap (`perf record`, the symbols of D2): 36% in the translated code, 34% in calls and returns through the glue (`enter` 13%, `native_ret` 6.6%, `vm_pop` 6.1%, `native_call` 4.1%, `vm_push_frame` 2.5%), 12% in the collector, 6% allocating, 2% in the primitives still called. What pays first, and in what order, is M10 to M15 below, from a profile taken after M9: calls and returns done by the templates, which D0 allows (the glue was M3's shortcut), then allocation inline; D3's option A waits for those, since a native `ret` gains nothing while every return goes through C. M7 also found that M1 had made `runevm` slower, 13 to 16% more machine instructions (`perf stat`), because `vm_pop`, `vm_top` and the push of a frame had left the file of the loop; they are inline in `vm.h` again, and `vm_fatal` and `vm_exit` are declared not to return |
| M8, the round-up | done but for retiring this roadmap, which is the owner's to decide: the list *To revisit* has to find a home first. The rest: `man/runeopt.1` and completions for bash and zsh, which `check-docs` holds to the version; `make install` installs `runeopt` (the self-hosted build, or a host's with `HOST`) with its runtime under `lib/rune/runtime`, which the installed wrapper passes (tried: installed into a prefix, translating and running `hello` outside the tree, uninstalled); a section on native programs in [runtime.md](../runtime.md); the rules of *Constraints* in `AGENTS.md` (written as the milestones needed them) |
| M9, save and restore (optional) | done, D11's option 1 with option 6: a native program carries on an image of its own program -- `RUNEVM_OPTIONS="--restore FILE"`, `Runtime.restore`, the child of `--emulate-fork` -- whoever wrote it, and `runeopt --from-image` makes the program of an image (`RbcImage`; a real constant is written as C's hexadecimal notation from its bits, with integers alone). The code has a table of the places an image stops at (after a CALL, and after `rt_save` and `posix_fork`); a restore checks that the image's program is the one the executable carries (code, functions, globals, constants, the constants read under the rounding mode a program starts with, since `strtod` follows the mode the image restores) and gives every frame its native return. An image of another program is refused, `Runtime.restore` raising `OS.SysErr` (`ENOEXEC`), as the owner decided. `tests/opt-skip.txt` is empty: `rt.fork_image` and the `.restore` tests run natively, images cross between `runevm` and native code both ways and with the 32-bit and PowerPC VMs, and the programs of `examples/runtime` give `runevm`'s output, but `become`, which becomes an image of another program. **M9 found a bug of the runtime**: an image lost every reference to the first object of the heap, whose distance 0 was read back as no object, so `runevm --restore` crashed on a program that named the first string constant afterwards; the reader keeps the distance plus one now, and `tests/lang/rt.save_first` pins it |
| M10, calls and returns in the templates | done: CALL and TAILCALL check the closure and its function index, push the frame (`func`, `ret_pc`, `base`, `closure`, `native_ret`) or, for TAILCALL, keep it, move the argument to the callee's local 0 and jump to the callee's entry for calls, a third column of `rune_functions`; that entry checks the room the frame needs against `stack_cap` and sets the locals but the first to unit, a store each, where `enter` had a loop. RET puts the result in local 0, pops the frame and jumps through `native_ret`. The glue (`native_call`, `native_tailcall`, `native_ret`) is the slow path: a value that is no closure, an index out of range, a full array of frames, the top level's RET. Found on the way: `bin/runevm-opt` kept its translations by the checksum of the bytecode alone, so a suite run after a change of `runeopt` or the runtime could run the programs the old ones made; `make` now empties the cache whenever it builds either again. `make check`, `make test-native-stress` and `make test-native-asan` pass. The gain is measured with the others' after M15 |
| M11, allocation in the templates | not started (est. 6-8%) |
| M12, a cheaper collector | not started (est. 3-6%, up to 12% by D14) |
| M13, the tag test of a match, fused | not started; waits for D13 (est. 4-6%) |
| M14, D3's option A, measured first | not started (est. 5-15% on programs made of calls) |
| M15, the values of a run in registers | not started (est. 5-10%) |

## Where we are

### The input

An `.rbc` is version 2 (`src/backend/emit.sml:10`, `vm/loader.c:88-91`). In
order, it holds:

* a constant pool of five kinds: int, word, real, string and char. Reals are
  stored as text, for `strtod`.
* a count of globals, which have no initialisers;
* a function table, each entry `{code_offset, nlocals, name}`;
* the code, where each instruction is one opcode byte and its `i32`
  operands;
* a file table and a line table, delta-encoded seven bits at a time.

The layout is in [bytecode.md](../bytecode.md) and the reader is
`load_program` (`vm/loader.c:76-201`). `bin/rune.rbc` is 639,267 bytes. It
has 1,046 constants, 1,514 globals, 2,343 functions and 109,677
instructions, which use 158 distinct primitives. Its line table has 20,474
entries.

There is no reader of `.rbc` written in SML. The only SML code that touches
the format is the writer, `emit.sml`. `runevm --disasm` is C
(`vm/loader.c:277-309`). `rune --dump-code` prints the code before it is
serialised (`src/backend/codegen.sml:317-329`).

The loader treats the file as untrusted, but its validation is about bounds.
`validate_program` (`vm/loader.c:209-263`) checks opcodes, operand ranges and
function offsets. It also checks that every jump target is the start of an
instruction (`:252-257`). It does not check that the target lies in the same
function, nor that the stack height is the same on every path into an
instruction. The interpreter does not need either check, because every pop
checks for underflow and every operand is bounds-checked when it is used.

### The instruction set, as a translator sees it

There are 34 opcodes (`vm/opcodes.def`). They drive a stack machine over
16-byte tagged `Value`s (`vm/vm.h:29-38`): a tag byte, seven bytes of padding
that the `mk_*` helpers never initialise, and an eight-byte payload. Heap
objects have an eight-byte header and are eight-byte aligned, so the
`Value`s in the heap are aligned to 16 bytes only every other time.

* **There is no arithmetic opcode.** Every operation on an int, word, real,
  char, string, array or file is `PRIM p`, a call through
  `prim_table[p](vm)` (`vm/interp.c:433-439`). There are 292 primitives
  (`vm/prims.def`). Each has the type `int (*)(VM *)`, reads its arguments
  from the top of the VM stack (`ARG(n)`, `vm/prims.c:13`) and pops them
  only once its result exists. It returns 0, or 1 when it raised (in which
  case `vm_raise` has already moved `pc`, `fp` and `sp` to the handler), or
  2, `PRIM_NEW_WORLD`, when `Runtime.restore` has replaced the program
  (`vm/vm.h:227-232`).
* **Every call goes through a closure.** Field 0 of a closure is the index
  of its function, not a code address (`vm/vm.h:43`, `vm/interp.c:339-363`).
  CALL pushes a frame `{func, ret_pc, base, closure}` (`vm/vm.h:108-113`), in
  which `ret_pc` is a bytecode offset. TAILCALL reuses the frame, and RET
  goes back to `ret_pc`.
* **Exceptions go to a bytecode pc.** A handler is `{pc, sp, fp}`
  (`vm/vm.h:115-119`). RAISE, or a primitive that raises, pops the innermost
  handler, restores its `sp` and `fp`, pushes the exception and continues at
  its `pc` (`vm/interp.c:164-189`). With no handler left it prints
  `runevm: uncaught exception ...` and a trace, and exits with status 1.
* **Any allocation can move every object.** TUPLE, CON, CLOSURE, NEWEXN,
  MKEXN and most primitives allocate. The collector is Cheney's and
  allocates a new to-space for every collection, so even the heap's base
  address changes. The value stack, the frames and the handlers grow with
  `realloc` (`vm/interp.c:47-55`, `:67-96`), so any call that can push
  invalidates a pointer into them.

### What the corpus does, and what it never does

A pass over the 422 programs parsed each function's code and followed the
stack height and the handler depth along every path, using the stack effect
that `vm/interp.c` gives each instruction. The programs hold 437,885
functions and 12,639,613 instructions. The pass found no exceptions to any
of the following:

* **Every jump is forward**, and every jump target lies in its own function.
  There are no loops in the bytecode: a `while` is a recursive function
  called `while`.
* **The stack height agrees at every join**: at a jump target, at a handler
  (its height plus the exception) and after a CALL. A translator can
  therefore know the height at every instruction, and the maximum height of
  every function. That maximum above the locals has a median of 2 and a mean
  of 2.6. The largest is 294, in the `<toplevel>` of the compiler, and the
  next is 74.
* **No TAILCALL and no RET happens with a handler of its own frame still
  installed.** The compiler never makes the body of a `handle` a tail
  position (`src/backend/codegen.sml:212-215`).
* **No function falls off its end.** Every function ends with RET
  (`src/backend/codegen.sml:243-244`).
* **1.9% of the instructions are unreachable**: 235,894 in all, of which
  119,482 are JUMPs and 116,332 are RETs. They are the RET that follows a
  function body ending in a tail call, and the JUMP past the `else` of an
  `if` in tail position.
* **The places a native program has to be able to resume at** are the
  512,450 instructions after a CALL, the 754,299 after a PRIM and the 4,174
  handlers. In `bin/rune.rbc` these are 4,881, 6,058 and 16.
* **`poly_eq` is 39% of all PRIM sites**: 291,530 of 754,299. Most of those
  are the test `CONTAG; INT t; PRIM poly_eq; JUMPIFNOT` that pattern matching
  compiles to (`src/core/matchcomp.sml:70`). It is followed by
  * `int_add` (45,541), `int_sub` (40,046), `string_concat` (32,504) and
    `int_lt` (28,481);
  * the other three comparisons of ints (about 13,000 each),
    `string_size` (14,085) and `ref_get` (12,621).

The static count of each opcode, over the corpus:

| Opcode | Sites | Opcode | Sites |
|---|---|---|---|
| LOCAL | 2,833,218 | SETLOCAL | 1,553,691 |
| JUMP | 866,614 | PRIM | 754,299 |
| SELECT | 578,848 | GLOBAL | 574,889 |
| CALL | 512,450 | INT | 465,341 |
| UNIT | 455,605 | RET | 437,885 |
| CLOSURE | 437,463 | JUMPIFNOT | 416,520 |
| TUPLE | 415,334 | POP | 347,267 |
| SETGLOBAL | 322,710 | CON0 | 237,621 |
| CONST | 218,880 | ENV | 212,444 |
| CONTAG | 198,926 | TAILCALL | 184,545 |
| CON | 169,447 | DECON | 128,914 |
| RAISE | 90,122 | MKEXN | 86,286 |
| BUILTINEXN | 80,383 | SELF | 40,080 |
| EXNCON | 5,162 | NEWEXN | 5,123 |
| PUSHHANDLER, POPHANDLER | 4,174 each | EXNARG | 1,086 |
| SETENV | 112 | HALT, JUMPIF | 0 |

These facts hold because of how `src/backend/codegen.sml` is written. The
loader promises none of them. A translator that relies on them has to check
them, and refuse a file that breaks them (D0, M2).

### The runtime the native code would link against

The draft names `heap.c`, `image.c` and `sys_posix.c`. Those three cannot be
linked on their own today:

* `image.c` needs `vm_release` from `main.c`, `validate_program` from
  `loader.c` and `vm_grow_stack` from `interp.c`.
* `prims.c` does all the arithmetic, so a native program cannot do without
  it. It needs:
  * `vm_exit` from `main.c`;
  * `vm_fatal`, `vm_raise`, `vm_raise_builtin`, `vm_cons`, `values_equal`
    and `vm_pop` from `interp.c`;
  * `line_at` from `loader.c`.
* `heap.c` needs only `sys_time_user` and `sys_time_sys`. `sys_posix.c`
  needs nothing but `sys.h`.
* `vm_release` and `vm_exit` live beside `main()` (`vm/main.c:26-69`).
* `vm_run` mixes starting a program (the builtin exceptions and the
  top-level frame) with the dispatch loop (`vm/interp.c:205-226`).
* `load_program` reads only from a path.

There is no library. Every VM is built by one `cc` call over
`VM_SRCS` (`Makefile:83-84`), and the Windows builds have a list of their own.
The whole Linux runtime is 5,085 lines of C: `prims.c` 2,120, `sys_posix.c`
1,207, `image.c` 664, `interp.c` 444, `loader.c` 309, `heap.c` 181 and
`main.c` 160.

### What the collector and the images ask of native code

The collector's roots are the value stack up to `sp`, the globals, the
constants, the closure of every frame and the builtin exceptions
(`vm/heap.c:89-97`). Nothing else is scanned: not the handlers, not a C
local, not a register. Native code whose every live value is on the VM's own
stack therefore needs no stack maps. A stack-machine translation keeps them
there anyway. It must reload any pointer it holds after anything that can
allocate. That includes the frame's closure, the constants and the base of
the stack.

An image refers to code only as function indices and bytecode pcs:
`vm->pc`, each frame's `ret_pc` and each handler's `pc`. It also contains
the whole bytecode (`vm/image.c:152-244`), and its reader checks the pcs
against that bytecode (`vm/image.c:600-621`). It is written only inside a
primitive, `rt_save` or an emulated `posix_fork`. The check accepts any
instruction boundary. That is right for the interpreter, but too lax for
native code, which can resume only after a CALL or a PRIM, or at a handler.
Two consequences:

* A native program that keeps its frames and handlers in bytecode terms
  writes the same image the interpreter writes.
* Resuming a native program needs a map from pc to native address, and only
  for those three kinds of place (D11).

### Counting

`vm->instructions` goes up once for each instruction dispatched, before the
instruction runs (`vm/interp.c:239`). An instruction that raises is counted,
and so is a primitive, whatever it does. Three things read the counter:

* `rt_instructions` (`vm/prims.c:2032`);
* `vm_exit`, which prints `--count` (`vm/main.c:57-62`);
* `write_image`.

A program can reach them only through a PRIM, an uncaught RAISE, or the RET
that leaves the top level. The bytes and objects counted begin with the
allocations made at start-up: the string constants in pool order
(`vm/loader.c:113`), then the eight builtin exceptions
(`vm/interp.c:211-217`). A native program has to make the same allocations
in the same order.

### Stack traces and the `Runtime` structure

A trace walks `frames[fp..0]` (`vm/interp.c:5-30`, `vm/prims.c:2060-2080`).
For each frame it takes the name from the function table and the position
from the line table, using `vm->pc` for the innermost frame and the next
frame's `ret_pc` for the rest. If the frames stay the VM's own,
`Runtime.trace`, `printTrace` and the uncaught-exception report work
unchanged.

The same holds for the rest of the structure (`lib/basis/runtime_sig.sml`),
because it all goes through primitives over VM fields:

* `stats` and `profile`, whose counters are listed under *Counting*;
* `collect`, `same` and `version`;
* `save`, which writes the image described above;
* `restore` is the exception: it replaces the running program (D11).

The examples in `examples/runtime` (`stats`, `profile`, `trace`,
`checkpoint`, `become`) exercise all of it.

### Tests, benchmarks and where they assume runevm

**Test runners.** Every runner takes the VM as a parameter:
`tests/run-tests.sh --vm CMD` runs `CMD [vmargs] prog.rbc [args]`
(`tests/run-tests.sh:66`), and `run-matrix.sh` uses `RUNEVM`. There are
already wrapper VMs: `bin/runevm-stress` and `bin/runevm-ppc64`, the latter
because "every runner takes --vm bin/runevm-ppc64 and needs to know nothing
of qemu". `tests/run-portability.sh` and `tests/run-windows.sh` show how to
run the suites again another way, with a skip list and a cross-check of
`--count`.

**Performance.** `make perf-check` reads budgets from the line
`runevm: count: N instructions, B bytes, O objects`
(`tests/perf/run-perf.sh:47-50`). `make perf` times each program of
`tests/perf` in every configuration of `run-matrix.sh --perf` and writes
`tests/out/perf/wall.md`. The last results, from 2026-09-20, are in
[basis-compat.md](../basis-compat.md):

* the VM runs plain code 20 to 80 times slower than the hosts' native code;
* the self-hosted compiler is 35 to 40 times slower than the MLton build of
  it ([performance.md](performance.md)).

In `run-matrix.sh`, `native:HOST` already means "the suite on the host's
own library". A configuration for Rune's native code needs another name.

**What assumes it is talking to runevm:**

* `.vmargs`: `rt.fork_image` passes `--emulate-fork`, and `rt.gc_stress`
  passes `--heap-size`.
* `.restore` runs `$vm --restore img` with no `.rbc` at all
  (`tests/run-tests.sh:107`).
* `rt.args_commandline` prints whether `CommandLine.name ()` ends in `.rbc`.
* The expected `.stderr` files, and `perf-check`, read messages that begin
  `runevm:`. The VM prints about a dozen of them.
* An emulated fork re-executes `/proc/self/exe` as
  `runevm --resume TOKEN` (`vm/sys_posix.c:511`). That argument list would
  collide with a native program's own arguments.
* `bin/rune-boot` passes `--heap-size`.

### Toolchain

On this machine:

* gcc 13.3, which builds position-independent executables by default, and
  clang 18;
* GNU binutils 2.42: `as`, `ld`, `readelf`, `objdump` and `addr2line`;
* gdb 15.1 and lldb 18.1.3;
* `llvm-dwarfdump-18` and `-17`, installed under versioned names only, with
  no plain `llvm-dwarfdump`;
* libdwarf's `dwarfdump` (20210528);
* perf 6.18, in `~/.local/bin` rather than from a package.
  `perf_event_paranoid` is 2, so perf can profile our own processes.

`scripts/doctor.sh` checks only `$CC` for the VM today. The mingw-w64
assemblers that `make windows` uses are there as well, which matters for
D2.

`runedoc` is the precedent for a third program built from the compiler's
sources. It was added in `65f2c1c`, which touched twelve files. Since then it
has gained:

* its own sources list, and build files for all five hosts;
* a cross-check of its output (`scripts/check-doc-cross.sh`);
* a test suite, perf budgets, a man page, completions, and a place in
  `make install`.

### Drift found on the way

M2 fixes all four:

* [bytecode.md](../bytecode.md) still gives the version as `1` in its layout
  block (line 16), while its text says 2.
* [architecture.md](../architecture.md) says the `.rbc` is written through
  `BinIO` (line 24). It is written through `TextIO`.
* `examples/hello.rbc` is an untracked file of version 1, which no VM loads.
* `man/runevm.1` and the completions do not mention `--restore`,
  `--emulate-fork` or `--resume`.

## Design decisions

### D0. What "a straightforward translation, without optimisation" allows

**Each instruction.** Every instruction of the `.rbc` becomes one template of
machine code, in the order of the bytecode. The template does what the case
for that instruction in `vm/interp.c` does. Nothing is reordered, merged or
dropped, and every instruction the interpreter would count is counted.

**State in registers, and when it must be exact.** A template may keep VM
state in registers, but only between the points at which it must be exact:

* `vm->sp` and `vm->fp` before every call into C;
* `vm->pc`, set to the pc after the instruction, before every PRIM, every
  RAISE and every path that ends the program (`vm_fatal`);
* `ret_pc`, written when CALL pushes a frame;
* no heap pointer held in a register across a call into C;
* after such a call, reload the base of the stack, the frames, the
  constants, the globals and the frame's closure.

**Two further freedoms**, neither of which changes which instructions run or
what any counter says:

* **The instruction counter is added once for each straight-line run of
  instructions**, not once per instruction (D6).
* **The primitives chosen in D12 are inlined.** The owner asked for this on
  2026-09-23. The C primitive stays as the slow path, so what the program
  sees does not change.

**What the translator may rely on**, having checked it:

* the stack height at every instruction;
* the maximum height of every function.

The stack's capacity can then be checked once, at a function's entry, for
its locals and its maximum height, where `vm_push` checks at every push. The
difference cannot be seen, except that when memory runs out the stack grows
a few values earlier.

**What the translator must refuse.** The translator refuses a file that
breaks the facts in *What the corpus does*, with a message. The interpreter
stays the place where any file the loader accepts can run.

### D1. The tool

The tool is a third program built from the compiler's sources, the way
`runedoc` is. It has its own sources list and a main file for each host. It
is built by MLton, SML/NJ in 64 and 32 bits, Poly/ML and itself, and its
output is compared across the five builds, as `check-doc-cross` does for
`runedoc`. "Reuse the compiler's code" means sharing the modules that
describe the machine: `Opcodes` and `Prims`, which are generated from the
`.def` files, and `src/util`.

What is new is an SML reader of `.rbc` with the stricter validation of D0.
It is also a disassembler, and its output must be the same as that of
`runevm --disasm`.

The reader has to reject an oversized operand or length with the same
message on every host. On the 32-bit SML/NJ an `int` has 31 bits, while the
file's operands are full `i32`s and its lengths `u32`s, so the reader reads
through `Word32` or `IntInf`.

The owner named the tool `runeopt` on 2026-09-23. From the name follow
`bin/runevm-opt` for the wrapper of D9, `rune:opt` for its configuration in
the matrix, and `scripts/opt.sh` for the script of M3.

Two other homes were considered and rejected:

* **A backend in `rune` itself.** The draft's input is an `.rbc`, and a
  backend in the compiler would change `bin/rune.rbc` and the bootstrap's
  budget.
* **A tool written in C.** It would not reuse the compiler's code.

### D2. What the tool writes

The tool writes GNU assembler text, which `cc` assembles and links. This
gives three things for nothing:

* **Line information.** One `.loc` directive per entry of the line table
  becomes a DWARF line table.
* **Unwind information**, from `.cfi_*` directives.
* **Symbols.** Each function gets one, mangled with its index, because names
  repeat: there are many `fn`s, and every program has a `<toplevel>`.

The text also keeps Windows in reach. The mingw-w64 assembler reads the same
syntax and writes PE/COFF.

**The rules the output follows:**

* **Position-independent.** Globals are reached by `lea sym(%rip)`, and the
  function and resume tables hold 32-bit offsets from a base. Absolute
  addresses would not link into a PIE.
* **A non-executable stack.** A `.section .note.GNU-stack` directive says
  so; without it ld 2.42 warns and makes the stack executable.
* **Symbolic offsets.** An `asm-offsets` header, generated from `vm.h` with
  `offsetof` and checked with `_Static_assert`, names every field that a
  template touches. The tool writes those names and not numbers, so its
  output does not depend on the layout of a struct, and it is byte-identical
  across hosts.
* **The output streams.** The assembler text for the compiler is estimated
  at tens of megabytes.

Writing ELF objects and DWARF directly would free the tool from the
assembler, at the cost of an ELF writer and a DWARF writer. That is left for
later.

### D3. Control flow -- decided: B

In both options the state stays in the VM's structures:

* every value lives on `vm->stack`;
* every call pushes a `Frame` with its `ret_pc`;
* every handler is a `Handler`.

This is what makes the collector, traces, `Runtime.stats` and images work
unchanged. The options differ only in how control moves.

**B, jumps only (recommended).** Native code runs on the C stack at a fixed
depth, inside one C-called entry point.

* CALL checks the closure, looks up the entry of its function in a table
  indexed by function, and pushes the frame. It stores the native return
  address in a new field of `Frame` and jumps.
* RET pops the frame and jumps through that field.
* A raise goes wherever `vm_raise` left `vm->pc`, through the table of
  handler addresses.
* The new field is not written to an image (images are written field by
  field, `vm/image.c:212-217`), and a restore fills it in again.

The argument for B's correctness is local: this is the `switch` of
`interp.c` with the dispatch taken out. It needs nothing that is specific to
a platform, it runs under ASan, and on Win64 or aarch64 only the layer for
calls into C changes.

Its cost is that every RET is an indirect jump, which the processor predicts
less well than a `ret`. Under B, `bt` in gdb or lldb shows the innermost SML
function and the entry point, not the chain of SML calls.

**A, native call and return.** A separate, large mapped stack holds one
16-byte machine frame per VM frame: a return address and padding, so that
every call into C is aligned.

* CALL is `call`, RET is `ret`, and TAILCALL is `jmp`.
* The `rsp` of a handler follows from `vm->fp`, so `Handler` needs no new
  field.
* Returns are predicted by the return stack buffer.
* With CFI, `bt` in a debugger shows the SML frames.

The costs:

* **Switching stacks** needs assembly or `mmap`, and the machine stack has
  to be sized. The VM promises that recursion is bounded by memory
  ([runtime.md](../runtime.md)), so the stack needs a guard page and a
  handler on `sigaltstack`, or a check at every CALL. It must still end
  with `runevm: out of memory (stack)`.
* **Space for C.** C runs on the same stack (`values_equal` recurses), so
  some space has to be kept free for it.
* **Tools that watch the stack.** ASan and valgrind need to be told about
  the switch. CET shadow stacks object to it.
* **Windows.** Its `__chkstk` probes and its exception handling check the
  stack limits in the TEB.

The owner chose B on 2026-09-23, with A perhaps to be tried later: a later
experiment in performance (M7).
It changes only the templates of CALL, TAILCALL, RET and RAISE, and the
glue. Timing fib and tak with A and with B at M3 would say little, because
a primitive call per arithmetic operation dominates both. The comparison
makes sense after M5.

### D4. The runtime as a library

M1 moves what the runtime needs out of `main.c` and `interp.c`:

* `vm_exit` and `vm_release`;
* the helpers for frames and handlers;
* a `vm_start` that does what `vm_run` does before its loop;
* `load_program_mem`, which loads an `.rbc` from memory.

With them, `heap.c`, `loader.c`, `prims.c`, `image.c` and the system layer
form `librune`. `runevm` is then `main.c` and `interp.c` linked against it.
A native program is its generated code, a C file of glue, and the same
library.

The glue gives the generated code entry points whose arguments are pointers
and integers only, such as `native_raise(vm)` and `native_prim(vm, p)`. A
`Value` is never passed by value from assembly. The System V ABI passes a
16-byte struct in two registers, while Win64 passes it by a hidden pointer.

This is a change to the VM core, so by `AGENTS.md` it is finished only when
`make check`, `make test-windows` and `make test-portability` all pass.

### D5. What the executable contains

The executable carries its `.rbc` whole, as data, and loads it at start-up
with the same loader. That gives several things with no new code:

* the constants are made in the same order, so the counts of bytes and
  objects agree from the first instruction;
* the function names and the line table are there for traces;
* the bytecode is there for images, which contain it and are checked
  against it.

Beside it the executable has three tables, each of 32-bit offsets:

* the native entry of each function;
* the native address of each place the program can resume at, keyed by pc.
  These are the instructions after a CALL or a PRIM, and the handlers
  (512,450, 754,299 and 4,174 in the corpus; 4,881, 6,058 and 16 in
  `bin/rune.rbc`);
* the handlers, which a raise needs.

Carrying the `.rbc` costs its size: 639 KB for the compiler. The machine
code is estimated at 20 to 40 bytes per instruction, which would be 2 to
4 MB for the compiler. M3 measures both.

### D6. Counting

The count is kept in a callee-saved register. A run of instructions that
ends at a CALL, TAILCALL, PRIM, RAISE, RET, JUMP or HALT, or just before a
label, adds its length when it begins. That is exact: the interpreter counts
an instruction before running it, so a PRIM that reads the counter sees
itself. Control leaves a run early only at a PRIM or a RAISE, and each of
those ends its run.

**Flushing.** The register is written to `vm->instructions` before every
PRIM and RAISE, before HALT, and before a RET that leaves the top level. No
other path can reach a reader of the counter. `vm_fatal` and the exits for
running out of memory end the program without printing the count
(`vm/interp.c:32-45`, `vm/heap.c`).

**Reloading.** The register is reloaded after a primitive answers
`PRIM_NEW_WORLD`, and on starting from an image.

**Proof.** The proof is empirical: `--count` must print the same three
numbers as `runevm` for every program of the suites (M4). Bytes and objects
agree only if every allocation goes through `vm_alloc` in the interpreter's
order. For example, `TUPLE 0` pushes a unit and allocates nothing
(`vm/interp.c:286`), and `--gc-stress` counts objects.

### D7. Debug information

**What is emitted.** A `.file` for each file of the `.rbc`, a `.loc` for
each entry of the line table, and a symbol for each function with its
bytecode name in a comment. `break list.sml:42` then works in gdb and lldb,
and so do stepping and `addr2line`, and perf attributes time to SML
functions.

**What is not emitted.** There is no DWARF description of values: a `Value`
is a tagged 16-byte cell that no DWARF type describes usefully. Under B
there is also no unwinding of SML frames. A Python command that walks
`vm->frames`, as `rt_trace` does, would give both gdb and lldb an SML
backtrace; both debuggers run Python.

**File paths.** The `.rbc` records its files as the compiler was given them,
relative and with no directory to resolve them from. The assembler records
its own working directory as `DW_AT_comp_dir`, and a debugger resolves a
relative path against it (M6 saw `addr2line` do so). So the tool is to take
an option for the source directory; until it does, a program translated
where it was compiled finds its sources. For the same reason the cross-host
check compares the `.s` files, not the executables.

**Two things M6 found.** A line entry that covers only instructions that
produce no code (a `POP`) has no row in the executable's table: two `.loc`
directives at one address leave the assembler one row, the last. And the top
level begins before the first entry of the table, so its first instructions
have no position, in the executable as in the `.rbc`.

**How it is checked:**

* `llvm-dwarfdump-18 --debug-line` and `dwarfdump` read the line table
  independently of GNU binutils, and `readelf --debug-dump=decodedline` and
  `addr2line` give binutils' reading. Two readers from different vendors
  catch an encoding that one of them would let through.
* gdb and lldb run a scripted smoke test: break at a line of a `.sml`, stop
  there, step.

### D8. The executable's command line and messages -- decided: as proposed

A native program's arguments are its own. `runevm`'s options come before
the `.rbc`, and a native program has no `.rbc` to put them in front of.
Precedents: MLton takes `@MLton ... --` on the command line and has
defaults fixed at link time with `-runtime`; GHC takes `+RTS ... -RTS`, the
variable `GHCRTS`, and `-with-rtsopts` at link time. The owner accepted
the following on 2026-09-23, and it is to be revisited later (see *To
revisit*):

* **Runtime options** (`--count`, `--stats`, `--heap-size`, `--gc-stress`,
  `--emulate-fork`) come from the environment variable `RUNEVM_OPTIONS`,
  written as `runevm` takes them. The tool can fix defaults at translation
  time. The native compiler needs that for its `--heap-size`, which
  `bin/rune-boot` passes today.
* **The token of an emulated fork** moves from `argv` into the environment,
  in `sys_posix.c` and `sys_win.c` alike. It can then never collide with a
  program's arguments. (M9 did it more simply: the child is started as
  `runevm --resume TOKEN` as before, and a native program takes that for the
  child of a fork only when its `argv[0]` is `runevm`, which no shell gives a
  program; `sys.h` is unchanged.)
* **Messages keep the prefix `runevm:`.** They are the runtime's messages,
  and the expected output, `perf-check` and `tests/external` all read that
  prefix. The alternative is the program's name, as GHC does, at the cost
  of a second set of expected `.stderr` files.
* **`CommandLine.name ()`** is the program as it was invoked, `argv[0]`. The
  wrapper of D9 gives the `.rbc`, the name the program has under `runevm`,
  in `RUNEVM_NAME`, so `rt.args_commandline` keeps its expected output. (M4
  found that setting `argv[0]` needs bash's `exec -a`, and bash takes the
  variable `_` out of the environment of what it runs, which a test of
  `Posix.ProcEnv.environ` saw.) The program reads both variables and takes
  them out of its environment, which is then the one it has under `runevm`,
  and the one its children get.

### D9. Tests

**The tool's own suite**, in `tests/opt`:

* **Refusals.** The malformed files of `tests/vm` are refused with the
  loader's messages, and files that break D0's facts are refused with the
  tool's.
* **`--disasm` parity** for every program of the corpus. A real is printed
  with C's `%g`, which SML does not have, so reals are left out of the
  comparison or a `%g` is written.
* **A synthetic `.rbc` that uses every opcode**, generated from
  `vm/opcodes.def`, so that an opcode without a template fails a test.
* **Identical assembler text** from the five builds of the tool.
* **The line table.** The DWARF line table, read as D7 describes, agrees
  with `--disasm` for every program.

**The existing suites, run natively.** Nothing about them changes:

* **A wrapper.** `bin/runevm-opt [vmargs] prog.rbc [args]` translates the
  `.rbc` into a cached executable, sets `RUNEVM_OPTIONS` from `vmargs`, and
  execs the executable. It is written by the Makefile, as
  `bin/runevm-stress` is.
* **`tests/lang` and `tests/vm`** run through
  `tests/run-tests.sh --vm bin/runevm-opt`, with a skip list,
  `tests/opt-skip.txt`, in the format of the portability and Windows lists.
  Every entry gives a reason, and a category stays only while a program is
  listed under it.
* **The Basis Library suite** runs as a configuration `rune:opt` of
  `run-matrix.sh`.
* **`--count`.** It agrees with `runevm` for every program: all of
  `tests/lang` and all of the Basis Library suite, not the five programs
  that portability samples.
* **Stress and sanitiser runs.** `--gc-stress` runs over the native suite;
  it is the test that finds a heap pointer kept in a register. The same
  suite also runs against an ASan build of `librune` and the glue.
* **The compiler, translated.** The compiler, translated by the tool,
  compiles itself to a `bin/rune.rbc` identical to the one the other five
  builds make. That is the largest single test there is, 970 million
  instructions, and it joins `check-cross`.

### D10. Performance

`rune:opt` joins `make perf`. The `.rbc` is compiled and translated before
the timed body, as `load()` already compiles, so `tests/out/perf/wall.md`
gains a column. The results go beside those of 2026-09-20 in
[basis-compat.md](../basis-compat.md), with the time taken to translate and
the size of each executable.

The symbols of D2 let `perf record` divide a run between templates,
primitive calls, allocation and collection. That tells a later roadmap
where optimisation would pay.

The draft forbids optimising the bytecode, so the gap to MLton will stay
large. Every value is 16 bytes in memory, and every call goes through a
closure and a frame. How large the gap is, M7 measures.

### D11. Save and restore -- decided: option 1, with option 6

The draft asks for strategies, presented as options. Six were considered.
Option 1 is recommended.

**1. Images stay in bytecode terms (recommended).** A native program writes
the image `runevm` writes, since its frames, handlers and pc are the VM's.
It follows from D3 and D5 at little cost.

To restore one, the program:

1. reads the image as `read_image` does;
2. checks that its program is the one embedded;
3. checks that every pc is one it can resume at (D5's second table);
4. fills in the native return addresses of the frames;
5. jumps to `vm->pc`.

"The one embedded" means the same code, function table, number of globals,
and number and kinds of constants. It needs to be this strict because the
native code has dropped the checks the interpreter makes at run time.

Images then cross in both directions. `runevm --restore` resumes an image
that a native program saved, and a native program resumes one that `runevm`
saved from the same `.rbc`. Prior art: Cog, the Squeak and Pharo VM, whose
snapshots hold bytecode and contexts, not machine code. Its compiled frames
are mapped back to bytecode pcs when a snapshot is taken, and machine code
is made again on resuming. HotSpot's deoptimisation maps compiled frames to
interpreter frames the same way.

**2. Dumping the process.** CRIU and DMTCP checkpoint a Linux process from
outside, and CRaC does it for the JVM using CRIU. Emacs's `unexec` wrote the
running process out as a new executable. It was replaced by the portable
dumper (`pdumper`) in Emacs 27 because it was fragile. An image made this
way belongs to one kernel, one C library and one executable. The runtime
roadmap chose images that do not depend on the machine
([runtime.md](../runtime.md)), and this option gives that up. Rejected.

**3. Native addresses in the image**, relative to the text segment. MLton's
`World.save` works this way, since its ML stack holds the labels of the
executable. OCaml's `Marshal` with `Closures` stores code pointers as
offsets together with a digest of the code, and refuses a mismatch. Such an
image is good for the one executable only, and gains nothing over option 1.

**4. First-class continuations.** Compile to continuation-passing style, or
capture continuations, and save the heap alone, as Gambit and Termite and
Kali Scheme serialise continuations. This changes the compiler, which the
draft rules out.

**5. Exec into the new world.** For `Runtime.restore`, once the image has
been read into a scratch VM (so that a bad image still raises in the old
world), exec `/proc/self/exe` with the restore requested. If the image
belongs to another program, exec `runevm`. The process keeps its pid and
the counters come from the image, but a descriptor without `CLOEXEC`
survives into the new world. This option is how option 1 could implement
`Runtime.restore`, and how it could handle a foreign image.

**6. Translate from an image.** `runeopt --from-image img` reads the program
out of the image and makes an executable that resumes it. This answers the
wrapper's `--restore img`, which comes with no `.rbc`.

**An image of another program.** `Runtime.restore` can load an image of a
program other than the running one (`vm/image.c:641-664`). A native program
cannot run that program's code. The choices were:

* refuse, with `OS.SysErr`;
* exec `runevm` on the image (option 5);
* link the interpreter into every native program as a fallback. That comes
  close to the "interpreter presenting as a linux executable" the draft
  rules out.

**Decided on 2026-09-23:** option 1, and option 6 as `runeopt
--from-image`. The others may be tried later. `Runtime.restore` of an image
of another program raises `OS.SysErr`, and a native program that cannot
restore at all yet (before M9) raises it for every image. A compiler or an
interpreter offered as a service may later let it continue into another
program.

For comparison, SML/NJ's `exportML` and `exportFn` write a heap image that
the runtime loads. Poly/ML's `SaveState` saves the heap without any thread's
stack, so it is weaker than `Runtime.save`, which resumes in the middle of a
call. SBCL's `save-lisp-and-die` writes a core file, which can be joined to
the runtime to make an executable.

**`--emulate-fork`.** It uses the same image, so M9 includes it. On Linux a
native program has a real `fork` (`vm/prims.c:1832-1837`), so only the test
`rt.fork_image` needs emulation before then.

### D12. Inlined primitives

The owner asked for this on 2026-09-23. A `PRIM p`, for a `p` on the list,
becomes a fast path inline:

* check the tags of the arguments;
* do the operation;
* test for overflow, zero or bounds as the C code does;
* push the result.

Anything the fast path does not handle calls the C primitive, which then
raises, or ends the program, with its own message. Such cases are:

* an argument of the wrong tag;
* an overflow, a division by zero, or an index out of bounds;
* for `poly_eq`, anything but two immediates of the same tag, other than
  reals.

Raising, fatal errors and every counter are therefore those of the C code
by construction. A PRIM still counts as one instruction. The candidates,
ordered by the site counts measured above:

* **`poly_eq` on two immediates of the same tag, other than reals.** This
  is the tag test of pattern matching, and 39% of all PRIM sites.
* **Int.** `add`, `sub`, `mul`, `neg`, the four comparisons, and `div`,
  `mod`, `quot` and `rem`, with their edge cases at `minInt` and `~1`.
* **Word.** `add`, `sub`, `mul`, the comparisons, `andb`, `orb`, `xorb` and
  `notb`, and shifts by 64 or more.
* **Char.** The comparisons and `char_ord`.
* **Real.** `add`, `sub`, `mul`, `div` and the comparisons, in SSE2. Its
  `MXCSR` holds the same rounding mode that C uses, including the one
  `IEEEReal.setRoundingMode` sets.
* **Perhaps:** `ref_get` and `ref_set`, which need no write barrier, and
  `array_sub`, `string_sub` and `string_size`.

At M5 the list is fixed by dynamic counts, which the static sites here only
approximate. The counts come from `runevm --trace` over `tests/perf`, and
`perf` over the native compiler.

**Keeping the two in step.** The list lives in one place in the tool. Each
entry has a differential test: a program that applies the primitive to its
edge values and prints the results, run under `runevm` and natively, with
the outputs compared. A check fails for an entry without such a test.
Inlining a primitive that allocates is out of scope.

### D13. Fusing an instruction sequence (decided: B)

D0 has every instruction become a template of its own, with nothing merged.
One sequence stands out in the profile of M10 to M15 below. The compiler
tests a constructor as `CONTAG; INT t; PRIM poly_eq; JUMPIFNOT l`
(`src/core/matchcomp.sml:70`), and those four instructions are about 9.5%
of the time of the native bootstrap. A template for the four together
would read the tag, compare it and branch, without the int and the bool in
between. It would still count four instructions, still stop on a value
that is not a constructor as CONTAG does, and apply only where no label
falls between them.

* **A, fuse in the translator (M13).** This relaxes D0 for this one
  sequence.
* **B, a fused opcode in the compiler.** This is item 3 of Phase B of
  [performance.md](performance.md), which helps `runevm` as much. It changes
  the bytecode, and Phase B waits for the owner's go-ahead.
* **C, neither.**

The owner decided on 2026-09-24: **B**. M13 is the new opcode.

### D14. How full the heap may be after a collection (decided: C)

Today the collector grows the heap until it is at most half full after a
collection (`vm/heap.c`). A quarter would roughly halve the number of
collections, for twice the memory. The collector is 17% of the native
bootstrap. Starting it with a heap of 1 GiB, one collection instead of 24,
takes 12% fewer cycles, which is the most any policy could gain. The
choice is the runtime's, so `runevm` would change with it.

* **A, half, as now.**
* **B, a quarter.**
* **C, an option**, with half as the default.

The owner decided on 2026-09-24: **C**. M12 is `--heap-fill P`.

## Constraints for all items

* **Every commit builds and passes `make check`.** A large milestone is
  split into several green commits.
* **The VM stays C99** ([performance.md](performance.md)). The glue is C99.
  The templates are the only assembly, and they are generated.
* **Five identical builds.** The tool builds with all five hosts, and they
  write the same assembler text, by the portability rules of
  [building.md](../building.md).
* **The instruction set** changes only through `vm/opcodes.def` and
  `vm/prims.def`, as before.
* **An opcode now has four implementations**: the interpreter's case, the
  template, the SML validator's stack effect, and the prose in
  [bytecode.md](../bytecode.md). M8 writes that into `AGENTS.md`, and
  `tests/opt`'s synthetic program fails for an opcode without a template.
* **The `.rbc` format has three readers and writers**: `emit.sml`,
  `loader.c` and the tool's reader. A change of version changes all three.
* **An inlined primitive changes with its C code.** Its differential test is
  what notices when it does not.
* **Target-specific code sits behind one module.** This covers choosing
  instructions, the ABI of calls into C, prologues and the directives of the
  object format, so that Win64 and aarch64 remain additions (see *Out of
  scope*).
* **D0 holds for every template.**

## Milestones

### M1. The runtime as a library -- M

D4, with no change in behaviour.

* `vm/runtime.c` takes `vm_exit`, `vm_release`, `vm_start` and the helpers
  for frames and handlers.
* `load_program_mem` joins the loader.
* The Makefile builds `build/librune.a` for each system layer and links
  `runevm`, `runevm-asan`, `runevm32`, `runevm-ppc64` and both Windows VMs
  against it. That removes the duplicated lists of sources.

Nothing a program can see changes. `--count` agrees to the byte, and
`make check`, `make test-windows` and `make test-portability` pass.

M1 and M2 do not depend on each other.

### M2. The `.rbc` reader, the validator and the tool -- M

* **The program.** The tool is a third program (D1), with its sources list,
  its main files, its five host builds and a cross-check of its output.
* **The reader.** `RbcRead` reads the format into SML values.
* **The validator.** `RbcCheck` does `validate_program`'s checks with its
  messages, then D0's:
  * stack heights that agree at joins, with no underflow;
  * jumps only within their function;
  * no TAILCALL or RET under a handler of the same frame;
  * no falling off the end.

  It computes each function's maximum height.
* **Disassembly.** `runeopt --disasm` prints what `runevm --disasm` prints.
* **Suite and checks.** `tests/opt` begins with the refusals and the parity.
  The analysis of *What the corpus does* becomes a test, run over every
  program that `make check` compiles.
* **The drift listed above** is fixed.

### M3. Every instruction translated -- L

* **The templates and the glue.**
  * All 34 templates, under D0, D3 B and D6, with every PRIM a call through
    the glue.
  * The tables of D5.
  * The start-up glue: load the embedded `.rbc`, `vm_start`, jump to
    function 0, and at the top-level RET, `vm_exit`.
  * `.loc` from the start, since it costs nothing.
* **Linking** with `cc`, against `librune`.
* **The synthetic program** of D9, which uses every opcode.
* **The first programs.** `examples/hello`, `fib` and `tak` run, with the
  same output and the same `--count` as under `runevm`.
* **Measured:** the size of the machine code, the time to translate and
  link, and the first timings (D5, D10).
* **`scripts/opt.sh prog.sml [-o exe]`** runs `bin/rune`, then the tool,
  then the link, for trying things out. It is not installed.

### M4. The suites, run natively -- L

* **The wrapper and the skip list** of D9, with the environment of D8.
* **`tests/lang`, `tests/vm` and the Basis Library suite** pass natively.
* **`--count`** agrees with `runevm` for every program.
* **Traces and the `Runtime` structure.** `Runtime.trace`, `printTrace`, the
  report of an uncaught exception, `stats`, `profile`, `collect`, `same` and
  `version` all work, and the programs of `examples/runtime` give the output
  they give under `runevm`, except `become` and the `restore` of
  `checkpoint`, which wait for M9.
* **Saving.** `Runtime.save` works natively. Until M9 the wrapper hands
  `--restore` to `runevm`, so the three `.restore` tests show that
  `runevm` resumes a native program's image. `Runtime.restore` raises
  `OS.SysErr` natively (D11), and `rt.fork_image` goes on the skip list,
  until M9.
* **The `--gc-stress` and ASan runs.**
* **The compiler, translated, compiles itself** to the same bytes.
* **`make test-native`** joins `make check`. The doctor gates it with a
  scope `native`, which requires `cc` and `as`. Without the tools it is
  skipped with a message, as the scope `windows` does. This is done here,
  not at the round-up, so that the templates cannot fall behind the
  interpreter.
* **Time.** The time `make check` gains is measured and recorded. Each
  translated program is cached against the hash of its `.rbc`.

### M5. Inlined primitives -- M

D12, done on a native suite that already passes, so that each primitive
inlined is a change that can be compared against the one before.

* **Choosing.** The list is fixed from dynamic counts.
* **The fast paths**, their differential tests, and the check that every
  entry has one.
* **The suite still passes**, with `--count` still equal.
* **Timing.** fib, tak and the programs of `tests/perf` are timed before and
  after.

### M6. Debug information, checked -- S

D7's checks run in `tests/opt` for every program:

* `llvm-dwarfdump-18` and `readelf` agree with `--disasm` about the line of
  every instruction;
* `addr2line` gives the right line for every entry of the table;
* gdb and lldb stop at a line of a `.sml`, where they are installed.

The `native` doctor scope warns about gdb, lldb, `llvm-dwarfdump-*` (found
by looking for its versioned names) and perf.

### M7. Performance -- M

* **`rune:opt` in `make perf`**, and the table in
  [basis-compat.md](../basis-compat.md) with it.
* **A `perf record` profile** of fib, tak and the compiler compiling itself,
  with what it says about templates, primitives, allocation and collection.
* **Optionally, A against B** (D3), now that primitives no longer dominate.

The result is a paragraph for the next roadmap on what optimisation would
pay for first.

### M8. The round-up -- M

* `man/runeopt.1` and completions, both checked by `check-docs`.
* `make install` installs the tool, `librune.a` and the glue, so that an
  installed tool links on its own.
* A section on native code in [architecture.md](../architecture.md) and
  [runtime.md](../runtime.md).
* The rules of *Constraints* in `AGENTS.md`.
* The roadmap is retired: what is worth keeping goes where the code is, as
  was done for the runtime roadmap.

### M9. Save and restore (optional) -- M or L

D11's option 1, with option 6:

* **Restoring natively.** `RUNEVM_OPTIONS=--restore` resumes an image of
  the program itself: the strict check of the embedded program and of the
  resume points, native return addresses filled in, and the counters
  reloaded.
* **`runeopt --from-image img`** makes an executable from the program in an
  image, and that executable resumes it. The wrapper uses it for
  `--restore img`.
* **`Runtime.restore`** resumes an image of the same program, and raises
  `OS.SysErr` for an image of another.
* **The child of an emulated fork.**
* **Crossing.** Images cross between `runevm` and native programs in both
  directions, including the 32-bit and PowerPC VMs of
  `make test-portability`.
* **The skip list is emptied** of its `RESTORE` entries.

### After M9: making native code faster

The owner asked on 2026-09-24 for milestones of performance, those of the
biggest gain and the lowest complexity first. They rest on a profile of the
native compiler compiling itself, taken on 2026-09-24 after the commits of
M9 (`perf record`). Each instruction of the code was given a symbol of its
own for the measurement (`.Lp` to `Lp_`, nothing else changed), so a sample
of the translated code names the bytecode instruction it belongs to:

| Where the time goes | Share |
|---|---:|
| Calls: `enter` 13.0% (half of it setting the locals of a new frame to unit, in a loop), `native_call` 6.1%, `native_ret` 4.7%, `native_tailcall` 3.2%, the reload of the frame at each entry 2.5% | 29% |
| The collector: `copy_obj` 8.8%, `collect_into` 3.8%, `memmove` 4.5%, and 2.3% in the kernel, mostly the fresh pages of every new to-space | 19% |
| Allocation: `vm_alloc` 4.0%, `vm_alloc_fields` 3.1%, `native_tuple` 2.4%, `native_closure` 1.0%, `native_con` 0.5% | 11% |
| The tag test of a match: CONTAG 5.2%, JUMPIFNOT 2.2%, `poly_eq` 2.1% | 9.5% |
| LOCAL 5.1% and SETLOCAL 4.6%: 16-byte values copied through memory | 9.7% |
| SELECT, mostly the load of the tuple itself | 7.6% |
| The primitives still called | 2% |

The gains below are estimates, from these shares. Each milestone is timed
before and after with `perf stat` (cycles and instructions, which stay
steady where the wall-clock time of a loaded machine does not), on `fib`,
`tak`, the programs of `tests/perf` (`make perf`) and the bootstrap. Each
keeps what every milestone before it kept: the suites natively, the counts
of `--count` equal to `runevm`'s, the stress and ASan runs, and the images.

### M10. Calls and returns in the templates -- M

Estimated gain: 15 to 20% of the bootstrap, more on programs made of
calls. The calls' 29% is C doing, one call at a time, what the templates
can do knowing the heights and the frame, and a loop over the locals that
the callee can unroll, since only it knows how many it has. This is within
D0: the code does what `vm/interp.c` does, and the frames are exact at
every call into C.

* **CALL** checks the closure (its tag and kind) and its function index,
  and leaves the rest to the glue's fatal path. It moves the argument into
  the closure's slot, which is where the callee's local 0 lies, and pushes
  the frame inline: `func`, `ret_pc`, `base`, `closure`, `native_ret`, with
  `vm_grow_frames` as the slow path. Then it jumps through the function
  table.
* **A function's entry** checks the room its frame needs (base, locals,
  highest stack) against `stack_cap`, with `vm_grow_stack` as the slow path.
  It sets its locals 1 to n - 1 to unit with n straight stores, which is
  half of what `enter` does today.
* **RET** puts the result in local 0 and pops the frame. At the top level it
  goes to the glue (`vm_exit`); otherwise it jumps through `native_ret`.
  **TAILCALL** is CALL with the frame kept.
* Traces, images and the collector see the same frames as before; the
  image tests of M9 and the gc-stress run are what show it.

### M11. Allocation in the templates -- S to M

Estimated gain: 6 to 8%. TUPLE, CON, CLOSURE, MKEXN and NEWEXN allocate by
bumping `heap_used`, when the object fits and `--gc-stress` is off. They
write the header and the fields from their slots, and add to
`bytes_allocated` and `objects_allocated`, which `--count` prints and which
must stay equal to `runevm`'s. Everything else goes to the helper of today,
which collects. The heap's base and limit are loaded from the VM after every
call into C, since a collection moves them. Within D0.

### M12. A cheaper collector -- S (the runtime, so `runevm` gains too)

Estimated gain: 3 to 6% with the heap as full as today, up to 12% by D14.
This changes `vm/heap.c`, which both programs share, so `make
test-windows` and `make test-portability` are part of it.

* Keep both semispaces, where the collector now allocates a new to-space and
  frees the old one at every collection: that is the kernel's 2.3%. The
  pair grows only when the heap does.
* Copy a small object field by field, not by `memcpy` (the 4.5% of
  `memmove`).
* How full the heap may be after a collection, as D14 decides: C, an
  option of `runevm` and of native programs, `--heap-fill P`, which the
  image carries as it carries `--gc-stress` (so the format of images
  becomes version 3).
* Not a collector of another kind: a generational collector is a roadmap of
  its own.

### M13. The tag test of a match, fused -- S to M (D13 = B)

Estimated gain: 4 to 6%. The compiler's test of a constructor,
`CONTAG; INT t; PRIM poly_eq; JUMPIFNOT o`, becomes one instruction,
`JUMPIFNOTTAG o, t`: pop a constructor value, nullary or not, and jump
unless its tag is `t`; it stops on a value that is no constructor as CONTAG
does. `Codegen` emits it for an `If` whose test is exactly that
comparison, which is what `MatchComp.testTag` builds. It is an opcode like
any other: the interpreter's case, the template, the stack effect of
`RbcCheck`, the loader's and `Rbc`'s check of its target, `bytecode.md`,
and `every-opcode.rasm`. Where runeopt's M13 of D13 = A would have kept
the count, B changes it: one instruction where there were four, so the
counts of `--count` and the budgets of `make perf-check` go down, and
`runevm` gains as much as native code. Appended to `opcodes.def`, the
opcode leaves the others their numbers, so the format keeps its version.

### M14. D3's option A: native call and return -- M to L (measured first)

Estimated gain: 5 to 15% on programs made of calls, less elsewhere. After
M10 a return is an indirect jump through the frame, which the processor
predicts poorly for a function called from many places, where a `ret` is
predicted by its return stack buffer.

* **The prototype first.** CALL, TAILCALL and RET as `call`, `jmp` and
  `ret` on a separate machine stack of 16-byte frames, timed on `fib`,
  `tak` and the bootstrap. The milestone goes on only if they gain.
* **What it takes** is D3's list: the stack switched to and sized, overflow
  still reported as `runevm: out of memory (stack)`, a handler's `rsp`
  taken from `vm->fp`, a restore that rebuilds the machine stack from the
  frames, and ASan told of the switch.

### M15. The values of a run in registers -- L

Estimated gain: 5 to 10%. Within a straight run, the values at the top of
the stack live in registers, and are stored to their slots only before a
call into C, a label or the end of the run. D0 already allows state in
registers between those points. A value pushed and popped within the run
(the operands of an inlined primitive, the tuple of a SELECT) then never
goes to memory. The largest change of these, since every template has to
know where its operands are, so it comes last.

**Not in these milestones**, since they change the compiler or the
bytecode rather than the translation: calling a known function directly,
values that are not boxed, and slots of a frame used twice. They are in
[performance.md](performance.md), for the VM and native code alike.

## To revisit

* **D8**, the executable's command line and messages. The owner accepted it
  as proposed on 2026-09-23, to be looked at again once native programs are
  in use: `RUNEVM_OPTIONS` (with `--restore FILE` in it since M9), the child
  of a fork known by `argv[0]` rather than a token in the environment, the
  prefix `runevm:`, and `RUNEVM_NAME`, which only the wrapper of the suites
  sets.
* **D3's option A**, native call and return: M14, after M10.
* **D11's other options**, and a compiler or interpreter offered as a
  service for `Runtime.restore` of another program.

## Risks

1. **The speed-up is smaller than hoped.** Dispatch is gone, but every
   value is still 16 bytes in memory, every call still goes through a
   closure and a frame, and every primitive not inlined is still a call.
   [performance.md](performance.md) found `vm_alloc_fields` at 16% of the
   bootstrap. Allocation and collection stay as they are. M3 gives the
   first number and M5 the second, so the risk shows early.
2. **The interpreter and the templates drift apart.** Every instruction now
   has two implementations. What guards them: `--count` equality and the
   full suite in `make check` (M4), the synthetic program for every opcode,
   and the rule in `AGENTS.md`.
3. **A pointer is kept across a call.** The collector moves every object,
   and `realloc` moves the stacks. A template that keeps an address across
   a call works until the first collection or growth at that point. Only
   `--gc-stress` (M4) and ASan find it reliably.
4. **The facts of D0 stop holding.** A change to `codegen.sml` could
   introduce a backward jump, or a join whose heights differ. The
   validator refuses such a file and the corpus test of M2 fails, which is
   the intent. The fix then goes in the compiler or the translator
   deliberately.
5. **The suite takes too long.** Translating and linking 400 programs costs
   time on every `make check`. The cache keyed by the `.rbc`, and a measured
   budget (M4), keep it in check.
6. **A dependency on the toolchain.** The tool needs `cc` and `as` when it
   runs, not only when it is built. The doctor reports them, and the
   installed tool says what is missing.
7. **The hosts disagree.** An `i32` read as an SML `int` on the 31-bit
   SML/NJ, or reals formatted differently for `--disasm`, would make the
   five builds write different output. `check-cross` finds it, and D1 says
   how to avoid it.
8. **Deep recursion**, under D3 A only.

## Out of scope

* **Optimisation that needs the compiler or the bytecode**: calling known
  functions directly, unboxing, slots of a frame used twice
  ([performance.md](performance.md)); inlining primitives that allocate;
  a collector of another kind. M10 to M15 are what the translation and the
  runtime can do alone.
* **Windows and processors other than x86-64.** D2, D4 and *Constraints*
  keep them additions. Windows needs a Win64 ABI layer, the mingw
  assembler, `sys_win.c` in `librune`, and PE/COFF with CodeView or DWARF.
  aarch64 needs a second instruction selector.
* **Writing ELF and DWARF directly**, without the assembler.
* **DWARF descriptions of values**, and an unwinder for SML frames in the
  debuggers.
* **A JIT.**
* **An installed driver from `.sml` to an executable**, or a `--native`
  flag in `rune`. The script of M3 is for trying things out.
* **`--trace`**, for which the interpreter remains.

## Verification

* **M1:** `make check`, `make test-windows` and `make test-portability`.
  `--count` agrees to the byte on every VM.
* **M2:**
  * `check-cross` with the tool, over the five hosts;
  * `tests/opt`'s refusals and `--disasm` parity;
  * the corpus test over every program `make check` compiles.
* **M3:**
  * hello, fib and tak give the same output and `--count` as under
    `runevm`;
  * the synthetic program runs every opcode;
  * the assembler text is identical from the five builds.
* **M4:**
  * `make test-native`, with every skip explained;
  * `--count` equality for every program;
  * the `--gc-stress` and ASan runs;
  * the compiler translated by the tool compiles itself to bytes identical
    to `bin/rune.rbc`;
  * `make check` with the native suite in it.
* **M5:**
  * the differential tests;
  * the suite and `--count` equality;
  * the timings before and after.
* **M6:** the checks of the line table with two independent DWARF readers,
  and the debugger smoke tests.
* **M7:** `make perf`, run on a machine with nothing else running, and the
  table recorded.
* **M8:** `make install` into a temporary prefix, then translate and run
  `examples/hello` with the installed tool. `check-docs` passes.
* **M9:**
  * images cross in both directions with `runevm`, and with the portability
    VMs;
  * `examples/runtime/checkpoint` and `become` give the output they give
    under `runevm`;
  * `rt.fork_image` passes natively.
* **M10 to M15:**
  * everything the milestones before kept: the suites natively, `--count`
    equal to `runevm`'s, the stress and ASan runs, the images;
  * the gain, timed before and after with `perf stat` (cycles and
    instructions) on `fib`, `tak`, `tests/perf` and the bootstrap, and a
    profile, recorded in the milestone's row;
  * M12 also `make test-windows` and `make test-portability`, since it
    changes the runtime.

## Where each line of the specification is answered

| Line of the draft | Where |
|---|---|
| a native code generation tool | D1, M2 and M3 |
| take an .rbc file and generate native linux executable in x64 | D1, D2, D5 and M3 |
| convert the rbc source map into native debugging data | D2, D7 and M6 |
| windows and non-x64 out of scope, but supportable | D2, D4, *Constraints* and *Out of scope* |
| reuse the compiler's code | D1 |
| straightforward translation, no interpreter, no optimisation | D0, D3 and D12, the last at the owner's later request |
| linked against heap, image and sys_posix as the runtime | D4 and M1. `prims.c` and parts of `interp.c`, `loader.c` and `main.c` are needed too (*The runtime the native code would link against*) |
| a new test suite for the tool | D9 and `tests/opt` (M2, M3, M6) |
| native code in the existing test suites | D9 and M4 |
| the real-time performance test compares native code with runevm and the other compilers | D10 and M7 |
| instruction counting (bytecode equivalent) and heap statistics | D5, D6 and M4 |
| stack traces | D3, D7 and M4 |
| save / restore, researched, as options for a final optional milestone | D11 and M9 |
