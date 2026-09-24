# Roadmap: native code (codegen)

The native code generator `runeopt`, planned on 2026-09-23 on branch
`codegen` and built as milestones M1 to M15 on 2026-09-23 and 24. How it
works is [native.md](../native.md), and how fast it is, and what would make
it faster, is [performance.md](performance.md). This file keeps what is
left to do, what is to be looked at again, and a short account of what was
done or discarded. The roadmap as it stood when the work ended -- the facts
it measured, every decision with its reasoning, the milestones, the
per-milestone analysis -- is `git show 938b29a:docs/plans/codegen.md`.

## Remaining work

* **Time native code again.** The native table of
  [basis-compat.md](../basis-compat.md) is M7's, before M10 to M15 made
  native code 1.75 times as fast. `make perf` on a machine with nothing
  else running, and the table and its notes replaced.
* **A source directory for the debug information.** The `.rbc` records its
  files as the compiler was given them, relative. A debugger resolves them
  against the directory the program was assembled in (`DW_AT_comp_dir`), so
  a program translated anywhere else does not find its sources. `runeopt`
  was to take the directory as an option. S.
* **Faster native code** is in [performance.md](performance.md):
  * items 9 (no reload of the frame after a return) and 18 (values in
    registers) change only the templates;
  * items 13, 14, 16 and 19 change them too, by the rules of *Keeping it in
    step* in [native.md](../native.md).
* **Retiring this file**, once the list below has a home. That is the
  owner's to decide.

## To revisit

### D8, the command line and messages

The owner accepted D8 as proposed on 2026-09-23, to be looked at again once
native programs are in use. A native program's arguments are its own:
`runevm`'s options come before the `.rbc`, and a native program has none.
The precedents:

* MLton takes `@MLton ... --` and has defaults fixed at link time with
  `-runtime`;
* GHC takes `+RTS ... -RTS`, the variable `GHCRTS`, and `-with-rtsopts`.

What was decided, and what might change:

* **Runtime options** come from `RUNEVM_OPTIONS`, written as `runevm` takes
  them, after defaults fixed at translation (`runeopt --options`). The
  native compiler needs those for its `--heap-size`, which `bin/rune-boot`
  passes.
* **The child of an emulated fork.** The proposal moved its token from
  `argv` into the environment, in `sys_posix.c` and `sys_win.c`, so that it
  could never meet a program's arguments. M9 did it more simply. The child
  is `runevm --resume TOKEN` as before, and a native program takes that for
  a fork's child only when its `argv[0]` is `runevm`, which no shell gives
  a program.
* **Messages keep the prefix `runevm:`**, as the runtime's messages. The
  expected `.stderr` files, `perf-check` and `tests/external` read it. The
  alternative is the program's name, as GHC does, at the cost of a second
  set of expected output.
* **`CommandLine.name ()`** is `argv[0]`.
  * The suites' wrapper gives the name the program has under `runevm`, its
    `.rbc`, in `RUNEVM_NAME`, so that `rt.args_commandline` keeps its
    output.
  * bash's `exec -a` would set `argv[0]`, but bash takes the variable `_`
    out of the environment of what it runs, which a test of
    `Posix.ProcEnv.environ` saw; so the wrapper is sh.
* **What in the suites assumes `runevm`:**
  * `.vmargs` (`rt.fork_image` passes `--emulate-fork`, `rt.gc_stress`
    `--heap-size`);
  * `.restore` tests, which run `$vm --restore img` with no `.rbc` (the
    wrapper uses `runeopt --from-image`);
  * `rt.args_commandline`;
  * about a dozen messages that begin `runevm:`;
  * `bin/rune-boot`'s `--heap-size`.

### D3's option A: native call and return

The owner chose B, the VM's frames and indirect jumps, on 2026-09-23, with
A perhaps to be tried later.

**What A is.** A separate, large mapped stack with one 16-byte machine
frame per VM frame: a return address and padding, so that every call into
C stays aligned.
* CALL is `call`, RET is `ret`, and TAILCALL is `jmp`.
* A handler's `rsp` follows from `vm->fp`.
* Returns are predicted by the return stack buffer.
* With CFI, `bt` in a debugger would show the SML frames.

**What it costs:**
* **The stack.** Switching to it and sizing it. The VM promises that
  recursion is bounded by memory, so the stack needs a guard page and a
  handler on `sigaltstack`, or a check at every CALL, and must still end
  with `runevm: out of memory (stack)`.
* **Room for C** on the same stack, since `values_equal` recurses.
* **Tools.** ASan and valgrind told of the switch; CET shadow stacks object
  to it.
* **Windows.** `__chkstk` and its exception handling check the stack
  limits in the TEB.
* **Images.** A restore that rebuilds the machine stack from the frames.

**Measured, not built** (M14, 2026-09-24). After M10 a return is an
indirect jump through the frame's `native_ret`, and a Xeon E5-1680 v3
(Haswell) predicts nearly all of them.
* The native bootstrap has 22.4 million branch misses in 7.0 billion
  cycles: all of them, at about 16 cycles each, are at most 5% of its time.
* 5 to 10% of the samples of `perf record -e branch-misses` land on the
  label a call returns to: 0.3 to 0.6% of the bootstrap.
* All the misses of `fib` are at most 1.7% of its time, those of `tak`
  2.1%.
* A would keep the call itself an indirect `call`, whose misses (10% of
  all) remain.

**Look again** on a processor whose indirect predictor is weaker, or for
code whose functions are called from many more places. The measurement is
`perf stat -e branch-misses:u`, and `perf record` of the same event on a
program whose labels are symbols (*Measuring* in
[performance.md](performance.md)).

### D11's other options, and restoring another program

Decided on 2026-09-23: option 1, images in bytecode terms, which native
programs write and resume as `runevm` does; and option 6, `runeopt
--from-image`. `Runtime.restore` of an image of another program raises
`OS.SysErr` (`ENOEXEC`). The owner noted that a compiler or an interpreter
offered as a service may later let it continue into the other program. The
options left:

* **2. Dumping the process.** CRIU and DMTCP from outside, CRaC for the JVM,
  Emacs's `unexec` (replaced by the portable dumper in Emacs 27 as
  fragile). An image then belongs to one kernel, one C library and one
  executable, which gives up the images that do not depend on the machine
  ([runtime.md](../runtime.md)). Rejected.
* **3. Native addresses in the image**, as MLton's `World.save`, or OCaml's
  `Marshal` with `Closures` and a digest of the code. Good for the one
  executable only, and nothing gained over option 1.
* **4. First-class continuations**, compiling to continuation-passing style
  and saving the heap alone, as Gambit, Termite and Kali Scheme serialise
  continuations. A change to the compiler.
* **5. Exec into the new world.**
  * Read the image into a scratch VM first, so that a bad one still raises
    in the old world.
  * Then exec `/proc/self/exe` with the restore requested, or `runevm` for
    an image of another program.
  * The process keeps its pid; a descriptor without `CLOEXEC` survives.
  * This is how a native program could continue into another program
    today.
* **Linking the interpreter into every native program** as a fallback. This
  comes close to the "interpreter presenting as a linux executable" the
  specification rules out.

For comparison: SML/NJ's `exportML` and `exportFn` write a heap the runtime
loads; Poly/ML's `SaveState` saves no thread's stack, so it is weaker than
`Runtime.save`, which resumes in the middle of a call; SBCL's
`save-lisp-and-die` writes a core that can be joined to the runtime.

### Windows and other processors

Out of scope so far, but the specification wants them possible later. The
target-specific code is kept in `src/opt/x64.sml`: the choice of
instructions, the ABI of calls into C, prologues, and the directives of the
object format.

* **Windows** needs:
  * a Win64 ABI layer for the calls into C;
  * the mingw-w64 assembler, which reads the same syntax and writes
    PE/COFF;
  * `sys_win.c` in the runtime library;
  * CodeView or DWARF in PE/COFF.

  The glue never passes a `Value` by value, since the System V ABI passes
  16 bytes in two registers and Win64 by a hidden pointer.
* **aarch64** needs a second instruction selector.

### Debugging

* **An SML backtrace in gdb and lldb.** Since the frames are the VM's, `bt`
  shows only the innermost SML function. A Python command that walks
  `vm->frames`, as `rt_trace` does, would give both debuggers one.
* **DWARF descriptions of values**, which a tagged 16-byte cell does not
  fit.

## Done or discarded

### The specification

The owner's draft, as written:

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

Every line is answered. The table of where is in `938b29a`.

The owner's additions and decisions:
* 2026-09-23:
  * arithmetic primitives inline (D12);
  * a script from `.sml` to an executable (`scripts/opt.sh`);
  * D3 = B, with A maybe later;
  * D8 as proposed, to revisit;
  * D11 = option 1 with `--from-image`, and `OS.SysErr` for another
    program's image;
  * the name `runeopt`.
* 2026-09-24:
  * D13 = B, a fused opcode in the compiler;
  * D14 = C, `--heap-fill`, half by default;
  * M10 to M15, each with an analysis of its gain and its cost in code;
  * `codegen` pushed after each commit.

### The milestones

The gains are cycles, geometric means over the eight programs of
`tests/perf` and the bootstrap.

| Milestone | Commit | What | Gain |
|---|---|---|---|
| M0 | `fe759b8` | the roadmap | |
| M1 | `51a80a6` | the runtime as a library, `build/librune.a` | `runevm` -15%, undone by `e656ead` |
| M2 | `4084dae` | the `.rbc` reader, validator and disassembler in SML | |
| M3 | `0c61f28` | every instruction translated, the glue, `scripts/opt.sh` | native 2.25x `runevm` |
| M4 | `a47b8d4` | the suites natively (`make test-native`), `--count` equal everywhere | |
| M5 | `132daca` | 56 primitives inline | native +21% |
| M6 | `0e97508` | debug information, checked by two DWARF readers and the debuggers | |
| M7 | `b47d49a` | `rune:opt` in `make perf`, a profile | |
| M8 | `7a3e960` | install, manual page, completions, docs, the rules in `AGENTS.md` | |
| M9 | `1a90a6b` | images carried on natively, `runeopt --from-image` | |
| M10 | `4da4372` | calls and returns in the templates | native +33% |
| M11 | `5c098e9` | allocation in the templates | native +14% |
| M12 | `769bec1` | both semispaces kept, `--heap-fill` | bootstrap CPU -21% native, -10% `runevm` |
| M13 | `4f8b145` | the fused tag test `JUMPIFNOTTAG` | `runevm` +6.4%, native +2% |
| M14 | `14dd12b` | option A measured, not built | at most 0.6% |
| M15 | `14df2e3` | a pushed local read in place (in part) | native +11% |
| | `913e9f0` | the analysis of every milestone | |

Native code ends 4.0 times as fast as `runevm` of the same build (2.45
after M9), 8 times slower than MLton's build on the compiler compiling
itself. `runevm` ends 1.12 times as fast as before M1, most of it M13.

**What it cost.**
* M10 to M15 grew `x64.sml` from 604 lines to 804, the collector by 25 and
  the compiler by 12.
* The gain per line was best where work moved from C into the templates
  (M10: about 105 lines for a third) and least where a change reached into
  the compiler for what native code had mostly taken already (M13, 54
  lines across four implementations, 2% natively).
* The lasting cost is what must now be kept in step: the templates copy the
  runtime's frame push and `vm_alloc`'s fast path (M10, M11), and M15's
  rule on instructions that read a local in place. Those rules are in
  [native.md](../native.md) and `AGENTS.md`.

### Found on the way

* **`e656ead`:** M1 had moved `vm_pop`, `vm_top` and the frame push out of
  the loop's file, costing `runevm` 13 to 16% more instructions. They are
  inline in `vm.h` again.
* **`aec3d91`:** an image lost every reference to the first object of the
  heap, whose offset 0 read back as no object. The offset is kept plus
  one.
* **M4:**
  * programs saw `RUNEVM_OPTIONS` in their environment;
  * bash drops `_` from the environment of what it runs;
  * LeakSanitizer found the copy of the name.
* **M2:**
  * C's `%.*s` ends a string at its first NUL;
  * awk loses the sign of `-0`;
  * SML/NJ 110.99.9 in 32 bits compiles `c - x`, with `c` its
    `Int.maxInt`, into code that overflows.
* **M6:** a line entry of instructions without code has no row, and the
  top level begins before the first entry.
* **M10:** `bin/runevm-opt` kept translations by the bytecode's checksum
  alone, so a suite could run programs an older `runeopt` made; the
  Makefile now empties the cache when it rebuilds either.
* **M12:** `cycles:u` counts no kernel time. It showed M12 as 5% where it
  was 21% in CPU time.

### Discarded

* **Option A of D3**, measured by M14: see *To revisit*.
* **Option A of D13**, fusing the tag test in the translator: the owner
  chose a fused opcode, which helps `runevm` as much.
* **D14's options A and B**, a fill of half or a quarter fixed. The option
  of C stays at half, since a quarter measured slower on this machine
  (less user time, more system time).
* **The rest of M15**, values in registers across a run: at most about 5%
  for a change of every template. It is item 18 of
  [performance.md](performance.md), with the other native items.
* **Huge pages for the heap**, and **removing store-forwarding stalls** in
  the templates: measured without gain ([performance.md](performance.md)).
* **Not planned:**
  * writing ELF and DWARF directly, without the assembler;
  * a JIT;
  * an installed driver from `.sml` to an executable, or `rune --native`
    (`scripts/opt.sh` is for trying things out);
  * `--trace` in native code, for which the interpreter remains;
  * inlining primitives that allocate.
