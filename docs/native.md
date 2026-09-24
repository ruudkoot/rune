# Native code

`runeopt` translates a `.rbc` into a program for Linux on x86-64, linked
against the runtime `runevm` is built from. This page is how it does that as
built: the rules its code keeps, what the executable holds, and what has to
change together when the runtime or the instruction set does. How it came
to be, and what is left to revisit, is [plans/codegen.md](plans/codegen.md).
How fast it is, and what would make it faster, is
[plans/performance.md](plans/performance.md). What a program sees of it is
under *A native program* in [runtime.md](runtime.md), and the modules are
listed in [architecture.md](architecture.md).

## The contract

**An instruction at a time.** Every instruction of the `.rbc` becomes a
template of machine code, in the order of the bytecode. The template does
what the instruction's case in `vm/interp.c` does. Nothing is reordered,
merged or dropped, and every instruction the interpreter would count is
counted. The one fused test, `JUMPIFNOTTAG`, is an opcode of the compiler,
not something the translator merges.

**The VM is exact where C can look.** The value stack, the frames and the
handlers are the interpreter's own structures, so the collector, traces,
`Runtime.stats` and images see the machine they see under `runevm`. State
may sit in registers between the points where it must be exact:

* `vm->sp` and `vm->fp` before every call into C that reads them (all but
  `vm_grow_stack`);
* `vm->pc`, the instruction after this one, before every call into C that
  can raise, collect, write an image or end the program;
* `ret_pc` and the rest of a frame when a CALL pushes it;
* no heap pointer is kept in a register across a call into C, and after one
  the code reloads the base of the stack; the frames, the constants, the
  globals and the closure are loaded afresh where they are used.

**Three freedoms**, none of which changes what runs or what a counter says:

* the count is added once for each straight run of instructions (see
  *Counting*);
* 59 primitives are done inline, with the C primitive as the slow path (see
  *Primitives done inline*);
* the value a LOCAL pushes may stay in its local, for the instruction after
  it to read there (see *A pushed local read in place*).

**What the translation relies on.** `src/opt/rbccheck.sml` checks it and
refuses a file that breaks it, with a message. `runevm` stays the place
where any file its loader accepts can run. It checks:

* on every path into an instruction, the stack height and the handler depth
  agree: at a jump target, at a handler (its height and the exception), and
  after a CALL;
* no path underflows, jumps out of its function, or runs off the end of it;
* no TAILCALL or RET happens with a handler of its own function installed;
* every operand fits 31 bits, so that the 32-bit SML/NJ build of `runeopt`
  reads what the others read.

Since the height before every instruction is known, a slot is an address in
the frame, and the room a function needs (its locals and its highest stack)
is checked once at its entry, where `vm_push` checks at every push. A jump
backwards within a function is allowed; the compiler emits none today, and
counting would handle one, since a jump target starts a run.

## Registers and the machine stack

| Register | Holds |
|---|---|
| `r12` | the VM |
| `r13` | `vm->stack`, reloaded after every call into C |
| `rbp` | 16 times the base of the current frame, reloaded where the frame changes: at a return, at a handler, at an entry from C |
| `r15` | the count of instructions executed |

A slot at height `k` is `16 * (nlocals + k)(%r13,%rbp)`. `rbx` and `r14` are
saved by `rune_enter` but unused. The code never pushes onto the machine
stack: every function runs in the frame of `rune_enter`, which its CFI
describes, so a debugger unwinds from any SML function to `main`, and every
call into C finds the stack aligned.

## Calls, returns and raises

The frames are the VM's (option B of the roadmap's D3). A frame is
`{func, ret_pc, base, closure, native_ret}`; `native_ret`, the machine
address the frame returns to, is never written into an image.

* **CALL** checks that the value is a closure and that its function index is
  in range, pushes the frame itself when the array of frames has room, moves
  the argument into the closure's slot (the callee's local 0), sets `rbp` to
  the new base and jumps to the callee's entry for calls.
* **A function's entry for calls** (the second column of `rune_functions`)
  checks the room the frame needs against `stack_cap`, calling
  `vm_grow_stack` if it must, and sets locals 1 to n-1 to unit, a store each.
* **TAILCALL** makes the same checks, keeps the frame (its `func` and
  `closure` change), moves the argument into local 0 and jumps.
* **RET** puts the result in local 0, pops the frame and jumps through
  `native_ret`. The code there reloads `r13` and `rbp` from the frame.
* **The slow paths** are `vm/native.c`'s `native_call`, `native_tailcall`
  and `native_ret`, the interpreter's cases taken out of the loop, which
  answer with the native code to go on at: for a value that is no closure,
  an index out of range, a full array of frames, and the RET of the top
  level, which ends the run.
* **RAISE** calls `native_raise`: `vm_raise` unwinds as it does for the
  interpreter, and `native_handler` finds the handler's code by its pc in
  `rune_handlers`. A handler's code reloads the frame.
* **PRIM** calls through `prim_table`. It answers 0 (go on), 1 (it raised) or
  2 (`Runtime.restore` made this another world); the last two go through
  `rune_unusual` to `native_unusual`, which answers with a handler or the
  place an image resumes at.
* **A check that fails** (a SELECT of what is no tuple, a global read before
  it is set) calls `native_fatal`, which stops with the interpreter's
  message.

## Allocation

TUPLE, CON, CLOSURE, NEWEXN and MKEXN allocate in the template when
`--gc-stress` is off and the object fits in the space left. They do what
`vm_alloc` does:

* bump `heap_used` by 8 + 16 n bytes;
* add to `bytes_allocated` and `objects_allocated`, which `--count` prints;
* write the header in two stores (kind, pad and constructor tag; length);
* write the fields from their slots.

Otherwise they call the glue's `native_tuple` and the like, which call
`vm_alloc` and may collect. MKEXN of a value that is no exception
constructor also goes to the glue, which reports it after allocating, as the
interpreter does.

## A pushed local read in place

A LOCAL emits nothing when the next instruction is in the same run, has no
position of its own in the line table, and is in the list `reads` of
`x64.sml`: an instruction that reads the top of the stack without writing it
in place. That instruction reads the local itself (`rslot`, `rpayload`), and
each of its slow paths first copies the value to its slot (`unforward`), so
the VM is exact before C sees it.

The rule this adds: an instruction in `reads` may read its top operand where
a LOCAL left it but must never write it in place, or it writes into the
local. That is why the primitives of one argument, which write their result
over their argument, are not in the list.

## Primitives done inline

`fastPrim` in `x64.sml` (`runeopt --inlined`) does the common case of 59
primitives:

* the arithmetic and comparisons of ints, words, reals and chars, and the
  conversions between them;
* `=` on two values that are neither pointers nor reals;
* `!` and `:=`;
* the length and elements of strings, vectors and arrays.

Each one checks its arguments' tags (and kinds and bounds), does the
operation, and tests for overflow, a zero divisor or an index out of
bounds as the C code does. Anything else calls the C primitive, which then
raises or stops with its own message, so a program cannot tell the
difference and a PRIM still counts as one instruction. Reals use SSE2,
whose MXCSR holds the rounding mode C uses. None of them allocates.

`tests/opt/prims.sml` runs every one on its edge values, natively and on
`runevm`, and wants the same output and counts; `tests/opt` fails if the
program stops using one of them.

## Counting

The count lives in `r15`. A run of instructions ends after a CALL, TAILCALL,
PRIM, RAISE, RET, JUMP, a conditional jump or HALT, and before a jump
target or a handler; each run adds its length where it begins. That is
exact: the interpreter counts an instruction before running it, and control
leaves a run early only at a PRIM or a RAISE, which end runs.

`r15` is written to `vm->instructions` before every PRIM and RAISE, before
HALT and before the RET that ends the top level. No other path reaches a
reader of the count. `vm_fatal` and running out of memory end the program
without printing it. `r15` is reloaded after a primitive answers with a new
world and when a program starts from an image.

`tests/opt/run-counts.sh` holds `--count` to `runevm`'s for every program of
`tests/lang`, and the Basis Library suite runs as `rune:opt`, so the bytes
and objects agree only if every allocation is made as the interpreter makes
it.

## What the executable holds

`runeopt` writes GNU assembler text (`runeopt -S` keeps it), which `cc`
assembles and links with `build/librune.a`: `vm/runtime.c`, `heap.c`,
`loader.c`, `prims.c`, `image.c`, the system layer, and the glue
`vm/native.c`.

* **Position independent.** Everything is reached through `%rip`, and the
  tables hold 32-bit offsets from their own start. A
  `.note.GNU-stack` section keeps the stack non-executable.
* **Symbolic layout.** `vm/native_offsets.c` prints the offsets and numbers
  of the VM's layout as `build/rune-offsets.s`, which the code includes. The
  translation writes names, never numbers, so it does not depend on the
  layout, and the five builds of `runeopt` write the same text
  (`scripts/check-opt-cross.sh`).
* **The `.rbc`**, whole (`.incbin`), loaded at start-up by the same loader.
  So the constants are made in the same order, and the counts agree from the
  first instruction; the names and the line table are there for traces; and
  the bytecode is there for images.
* **`rune_functions`**: three numbers for each function, its entry from C,
  its entry for calls, and its highest stack above its locals.
* **`rune_handlers`**: the code of every handler, by pc.
* **`rune_resume`**: the places an image can stop at, by pc.
* **`rune_options`**: what `runeopt --options` was given.
* **Symbols**: each function has one, its name and its index
  (`place#235`), since names repeat.

## Images

A native program writes the image `runevm` writes, since its frames,
handlers and pc are in bytecode terms. It resumes one, whoever wrote it, if
the image's program is its own. That covers `RUNEVM_OPTIONS="--restore
FILE"`, `Runtime.restore`, and the child of `--emulate-fork`.

* **The places an image can stop at** are the instruction after a CALL and
  the instruction after `rt_save` and `posix_fork`, whose code (a `.Lr`
  stub) reloads the frame first. Handlers are in `rune_handlers`.
* **Restoring:** `same_program` compares the image's code, functions,
  globals and constants with those carried. It reads the constants under
  `FE_TONEAREST`, since `strtod` follows the rounding mode the image has
  restored. `prepare_resume` then gives every frame its `native_ret` from
  `rune_resume`, checks that every handler and the pc are places of this
  code, and makes room on the stack.
* **An image of another program** is refused. `Runtime.restore` raises
  `OS.SysErr` with `ENOEXEC`, and `--restore` exits with a message.
* **`runeopt --from-image`** makes the program of an image (`RbcImage`),
  writing each real constant as C's hexadecimal notation from its bits.

Images cross between native programs and every VM, of every width and byte
order.

## Debug information

A `.file` for each file of the `.rbc`, a `.loc` where each entry of its line
table begins, CFI for every function, and a symbol for each. gdb and lldb
stop at a line of an `.sml`, lldb names the function, and `addr2line` and
perf name SML functions.

Its limits:

* **Entries without code.** An entry that covers only instructions that
  emit no code (a POP) has no row, since two `.loc` at one address leave
  one. A LOCAL left in its local is not left so before an instruction with
  a position of its own, which keeps the LOCAL's row.
* **Relative paths.** The `.rbc` records its files as the compiler was
  given them, and a debugger resolves them against the directory the
  program was assembled in (`DW_AT_comp_dir`). A program translated where
  it was compiled finds its sources.
* **Backtraces.** Since the frames are the VM's, `bt` shows only the
  innermost SML function.

`tests/opt/run-debug.sh` checks the line table as `llvm-dwarfdump` and
`readelf` read it against the positions `runeopt --disasm` prints, checks
`addr2line` on every function, and runs gdb and lldb.

## The command line and the environment

* **The options of `runevm`** (`--count`, `--stats`, `--heap-size`,
  `--heap-fill`, `--gc-stress`, `--emulate-fork`, `--restore`) come from
  `runeopt --options` and then the environment variable `RUNEVM_OPTIONS`.
* **`RUNEVM_NAME`** is the name `CommandLine.name ()` gives. The suites'
  wrapper sets it to the `.rbc`.
* **Both variables** are taken out of the environment, so the program and
  its children see the environment they would see under `runevm`.
* **Messages** begin `runevm:`, as the runtime's always have.
* **The child of an emulated fork** is started as `runevm --resume TOKEN`.
  A native program takes itself for one only when its `argv[0]` is
  `runevm`, which no shell gives a program.

## Tests

* **`make test-opt`** (`tests/opt/run-opt-tests.sh`):
  * the loader's refusals with its messages, and the contract's with
    `runeopt`'s;
  * `--disasm` against `runevm --disasm`;
  * `every-opcode.rasm`, which runs every instruction;
  * `prims.sml`;
  * images crossing both ways, and the image of another program.
* **`make test-native`**, part of `make check`:
  * `tests/lang` and the Basis Library suite run through `bin/runevm-opt`,
    a wrapper that translates each `.rbc` once, keeping it by its checksum
    (the Makefile empties that cache whenever it builds `runeopt` or the
    runtime again), with `tests/opt-skip.txt`, which is empty;
  * `--count` against `runevm`;
  * the native compiler compiling itself to `bin/rune.rbc` byte for byte;
  * the debug information.
* **`make test-native-stress`** and **`make test-native-asan`**, outside
  `make check`: the suites with a collection every 101st allocation, and
  with the runtime built with ASan and UBSan. The stress run is what finds
  a heap pointer kept across an allocation.
* **`check-cross`** runs `scripts/check-opt-cross.sh`, which wants the same
  output from the five builds of `runeopt`.

## Keeping it in step

`AGENTS.md` has the short form of these rules.

* **An opcode** has its description in `src/isa/stack.sml` -- its operands,
  stack effect, flow and body, from which `runeisa` writes the interpreter's
  case, the loader's and `Rbc`'s checks and `RbcCheck`'s effects -- its
  template, which MLton's build refuses to go without, a helper in
  `vm/native.c` if it calls into C (for a shared body, `op_<NAME>` of the
  generated `vm/ops.h`), its prose in [bytecode.md](bytecode.md), and a use
  in `every-opcode.rasm`.
* **A field of the VM** that the code touches is named in
  `vm/native_offsets.c`, never written as a number.
* **A primitive done inline** changes with its C code, and `prims.sml` has
  its edge cases.
* **Frames:** the templates of CALL, TAILCALL, RET and the entry for calls
  do what `vm_push_frame`, `native_call` and `native_ret` do. A change to
  `Frame` or to how a frame is pushed changes them too.
* **Allocation:** five templates copy the fast path of `vm_alloc`: when it
  collects, `--gc-stress`, the size, the header, the counts. A change to the
  allocator, a generational collector for one, changes them too. So do the
  inline `:=` and `Array.update`, for a write barrier.
* **`reads`:** an instruction in it never writes its top operand in place.
* **Resuming:** every place a frame returns to must be in `rune_resume`.

What could still go wrong, and what would notice:

* **The interpreter and the templates drift apart:** `--count` equality and
  `every-opcode.rasm`.
* **A template keeps a pointer across a call into C:** it works until the
  first collection or growth at that point. `--gc-stress` and ASan find
  it.
* **The compiler emits what the contract forbids:** `runeopt` refuses the
  file and `make test-native` fails. The fix then goes in deliberately.
* **The hosts disagree** (an `i32` in a 31-bit `int`, a real printed
  differently): `check-opt-cross`.
* **A missing toolchain:** `runeopt` needs `cc` and `as` when it runs, and
  the doctor's `native` scope reports them.
