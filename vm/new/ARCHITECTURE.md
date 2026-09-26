# vm/new as built

The virtual machine for the register bytecode, as it is: enough, with the
sources it names, to build it again. Every change to `vm/new` keeps this
current (`AGENTS.md`). What is planned for it is
[docs/plans/jit.md](../../docs/plans/jit.md); what a program can count on is
[docs/runtime.md](../../docs/runtime.md); the instruction set is described
in [docs/bytecode.md](../../docs/bytecode.md) and `src/isa/regs.sml`.

## What it is made of

`bin/runevm-new` is `vm/main.c`, `vm/new/interp.c`, `vm/new/isa_regs.c`,
`vm/new/jit.c` and the compiler in `vm/new/jit/` linked against
`build/librune.a`, the runtime `runevm` is built from
(`Makefile`, `bin/runevm-new`): the heap and collector (`vm/heap.c`),
frames, handlers, raising and traces (`vm/runtime.c`), the loader
(`vm/loader.c`), the primitives (`vm/prims.c`), images (`vm/image.c`) and
the system layer (`vm/sys_*.c`). The archive also holds the stack
bytecode's part (`vm/isa_stack.c`); `vm/new/isa_regs.c` is linked before
it and takes its place: the fingerprint an `.rbc` and an image carry, the
check of a program, the disassembler. The Windows, 32-bit and PowerPC
builds (`bin/runevm-new.exe`, `bin/runevm-new32.exe`, `bin/runevm-new32`,
`bin/runevm-new-ppc64`) and the sanitiser build are made from the same
sources with `vm/isa_stack.c` left out (`NEW_SRCS`, `WIN_NEW_SRCS`).

The generated files -- `vm/new/regs.def`, `regops.h`, `reg_cases.h`,
`reg_labels.h`, `jit_emit.h`, `jit_cases.h` and `src/backend/regcodes.sml`
-- are written by `runeisa`
from `src/isa/regs.sml` (`make isa`; `make check-isa` fails when they are
stale) and committed, so that the VM builds with a C compiler alone.

## Values, objects and the heap

As `runevm`'s ([docs/runtime.md](../../docs/runtime.md)): a `Value` is 16
bytes, a tag byte and a payload of 8 (`vm/vm.h`), with the tag and its
padding also one 64-bit word, the header, so that a value is made in two
registers and stored in two stores (a byte store read back as 16 bytes
stalls); objects have an 8-byte header and a payload in multiples of 16;
the collector is a Cheney two-space copier that runs only inside
`vm_alloc`, with the value stack below `sp`, the globals, the constants,
each frame's closure and the built-in exceptions as its roots. There are
no stack maps and no write barrier: every slot carries its tag, and the
stores into the heap are `SETENV`, the primitives `ref_set` and
`array_update` (in `vm/prims.c`, and in the loop through `HEAP_STORE` of
`vm/new/fastprim.h`) and a few more primitives.

## Frames, registers and the stack

A frame is `{func, ret_pc, base, closure, native_ret, result}` in the
array `vm->frames` -- `result` the register of the caller's `RESULT`,
recorded when the frame is pushed, so that a return writes into it
without decoding the caller's code (M7; `UINT32_MAX` where the caller
takes the value from the stack; not in an image, made again from the
code at `ret_pc` when one is read); the handlers `{pc, sp, fp, native}`
are a second array; the value stack a third. All three grow by doubling (`realloc`), which moves the
value stack.

A function's registers are its slots on the value stack from its frame's
base, `nlocals` of them (the function table; the last is the scratch
register the compiler uses for a value nothing reads). They start as
`unit`, and a register no longer used still holds a value, which the
collector sees. Above the registers a frame pushes only the arguments of
a primitive, the value a call returns and the exception a raise leaves
for `CATCH`: the checker works out how deep that goes for each function
(`maxstack`: the arity of its widest `PRIM` or `PRIMPUSH`, or 1), a call
makes room for `nlocals + maxstack` (`ROOM`), and a push does not check.
`make_room` does the same for the frames of an image or of `vm_start`.

Calls: `CALL f x` and `CALLK f n a...` push a frame whose base is the
caller's stack pointer, make the callee's registers there (the argument,
or the `n` arguments, then `unit`) and enter its code; `TAILCALL` and
`TAILCALLK` replace the frame, the arguments copied above the frame first
and moved down. `RET s` pops the frame and, since the caller goes on at a
`RESULT d`, writes the value into the caller's register `d` and passes
over the `RESULT` (one instruction fewer per call in `--count`); where the
instruction at `ret_pc` is not a `RESULT` -- a program resumed from an
image stops at one with its value on the stack -- the value is pushed and
`RESULT` takes it. A raise (`vm_raise`) resets the frame, the stack and
the handlers to the innermost handler's, pushes the exception and enters
the handler's code, which begins with `CATCH d`.

## The loop

`vm/new/interp.c` defines the words the bodies of `src/isa/regs.sml` are
written in and includes `vm/new/reg_loop.h` twice, as `loop_fast` and as
`loop_traced` (`--trace`). The loop keeps in its own variables the
program's code, the pc (already past the instruction being run), the
count of instructions, the frame, the frame's registers (`base`) and the
stack pointer (`sp`):

* `R(x)` is register `x`; `LIST(i)` the `i`-th register of the
  instruction's list; `PUSH`, `POP` push and pop above the registers,
  unchecked;
* `SYNC()` writes `sp`, the pc and the count to the VM, before anything
  that reads them there: the collector (every allocation), a raise, a
  primitive, `vm_push_handler`, a fatal error; `RELOAD()` reads back the
  code, the pc, the frame, `base` and `sp` after anything that may have
  changed them or moved the stack; `ROOM(top, fn)` makes room for a frame
  of `fn` at `top`, and reloads `base` and `sp` if the stack moved;
* `ENTER(slot, fn)` makes `slot` the registers and enters `fn`'s code;
  `FATAL(...)` is a fatal error at this instruction; `EXPECT(v, kind,
  what)` the object `v` points to, of that kind, or a fatal error; `NEXT`
  goes on to the next instruction.

Each case (`reg_cases.h`, generated) reads its own operands -- the fixed
ones, and for a list where it begins and how long it is (a count operand,
or the arity of the primitive named) -- moves the pc past the instruction,
counts it, does its body and goes on. Under gcc and clang the cases are
labels and `NEXT` a computed goto through the table of `reg_labels.h`;
elsewhere, and with `-DRUNE_SWITCH`, a `switch`.

`PRIM p d a...` first asks `prim_fast` (`vm/new/fastprim.h`) to do the
primitive from the registers: the common case of the primitives `runeopt`
does in line -- the arithmetic and comparisons of ints, words, reals and
chars, `=` on values not in the heap, `!` and `:=`, the length and elements
of strings, vectors and arrays. It gives the result `vm/prims.c` gives or
declines (an overflow, a divisor of zero or of `~1`, an index out of
bounds, an argument of the wrong kind), and then the arguments are pushed,
the VM made exact, the primitive called and its result popped, or its
raise taken. Either way a `PRIM` counts one.

## The driver and the JIT's view of a program

`vm_loop` is a driver (`vm/new/jit.h`): it runs whatever frame is on top
at that frame's tier -- the interpreter's, or the native code the JIT
made -- and no engine calls another. The interpreter hands the VM back
to the driver, exact, when the function it is about to enter has a
native entry (`HANDOVER` in `CALL`, `CALLK`, `TAILCALL` and `TAILCALLK`)
and when a `RET` lands in a frame whose caller left a native return
address (`RETURN_NATIVE`); native code hands it back when it must run an
interpreted frame or returns into one. So the machine stack is one C
frame deep whatever the program does, plus the call into C in progress:
`make test-new-jit` runs a recursion 200,000 deep under a machine stack
of 1 MB with every function handed to the JIT. That is what lets frames
be switched (green threads), copied (continuations) and rebuilt
(deoptimisation) later.

The JIT's view of the program (`JitProgram`, made by `jit_program` when
the driver first sees a program and again when it becomes another,
`Runtime.restore`) is a code object per function: its entry, NULL while
it is interpreted; its tier; the counters tier 0 keeps for the tiering
policy; and its code's table of pc to address. An entry is published
last, with one store. `--jit=off` runs the interpreter alone, `--jit=all`
gives every function an entry at load, `--jit=baseline` (the default)
compiles a function when its counters say so, `opt` is tier 2 (M9);
`--jit-stats` prints at exit what the JIT did.

**Tiering (M6).** Tier 0 counts, per function, its calls (in
`HANDOVER`, at every call) and its work -- the iterations of its loops
(in `BACKWARD`, at every `JUMP` back) and the calls it makes (in
`HANDOVER` too, for the caller) -- and compiles the function at the
threshold (`--jit-calls=N`, `--jit-work=N`; the defaults are the
sweep's, docs/plans/jit.md M6). The work counts for a function called
once that runs long: the compiler's top level, or a driver loop; its
code is entered when its next callee returns. The counters are instruction-based, so
which functions are compiled, and when, is the same on every run of a
program, and `--count` is the same in every mode. The interpreter goes
on in a function's code wherever a run of instructions begins: the
table of pc to address (`jit_osr`) has an entry for every target of the
compiler's scan -- a jump's target, a loop's head, a handler, the
instruction after a call, the `RESULT` after a `PRIMPUSH` -- and since a
run's count is added where the run begins, entering there is exact.
So a loop that got hot is entered at its head with the frame as it is
(`BACKWARD`), a frame pushed before its function was compiled goes on
in the code when its callee returns (`RESUME_NATIVE` in `RET`), a
handler pushed by the interpreter runs its code when raised into
(`RESUME_NATIVE` in `RAISED`), and the driver enters the code of any
frame it is handed at such a place -- the top level's at its first
instruction, an image's at its resume point. There is no OSR exit:
tier 1's frame is the interpreter's, so there is nothing to
reconstruct; leaving code for the interpreter is handing the VM back.

**Invalidation.** `jit_invalidate` resets a function's entry and its
counters and frees its table, and walks the VM's frames and handlers:
every `native_ret` and `Handler.native` that lies in the function's
code becomes NULL, so that a return or a raise into it goes to the
interpreter, which goes on from `ret_pc` or the handler's pc. That is
the whole of it, because the frames are the VM's (D4) and because no
native code is on the machine stack while the interpreter runs (the
driver's protocol): invalidation is only ever called from tier 0. The
code's bytes stay in the region (dead bytes, counted by `--jit-stats`;
reclaiming them is a later concern). `--jit-stress=N` invalidates the
callee's code at every Nth call into compiled code, so that
`scripts/check-jit.sh` holds every program to the interpreter's output
and counts while functions are compiled, entered mid-way, invalidated
and compiled again.
`--jit-check` allocates executable memory through the system layer
(`sys_code_alloc`, `sys_code_protect`, `sys_code_flush`,
`sys_code_free`; `vm/sys.h`), writes a few bytes of this machine's code
into it and runs them. A VM built with `RUNE_JIT=0` has the interpreter
alone and refuses `--jit`.

`jit_run` enters native code through the enter stub (*Tier 1*). Under
`--jit=all` every function is compiled when the program is first seen
(since M5; M4 compiled the leaves); a call from interpreted code into
compiled code, a return out of it and a raise into a handler of the other
tier (`RAISED` in the loop's words) each cross the driver once, which is
the cost of the protocol, measured in M3 with stubs for entries.
`--jit-only=LO-HI`, `odd` or `even` gives code to those functions alone:
for finding a function whose code is wrong by halving, and for the run of
`scripts/check-jit.sh` in which every other function is compiled, so
that calls, returns and raises cross between the tiers both ways.
`--trace` runs the interpreter alone. `RUNEVM_JIT` in the environment
names the mode where no `--jit=` does, for the runners that start a VM
they cannot give options.

## Tier 1: the baseline compiler

`vm/new/jit/` compiles a function of the register bytecode to x86-64
machine code (docs/plans/jit.md, D3 and M4): one instruction at a time,
in the order of the bytecode, each doing what its case in the loop does,
in the same frame, with every value in its slot. It is `runeopt`'s
contract (docs/native.md) for the register bytecode, at run time, in C.

* **`x64.h`, `x64.c`**: the encoder. A buffer of bytes, labels bound and
  patched (a rel32 to a label, or a table entry relative to a table's
  start), and the instructions the macro-assembler is written in: moves,
  16-byte copies through an xmm register, arithmetic, SSE2 on doubles,
  branches, calls. Nothing here knows a Value or a VM.
* **`masm.h`, `masm.c`**: the macro-assembler, and the conventions the
  code keeps. `r12` is the VM, `r13` the value stack, `rbp` the frame's
  base as an index, `r14` its registers (`r13 + 16 rbp`), `r15` the count
  of instructions; register k is the 16 bytes at `[r14 + 16 k]`. The
  machine stack holds only the call into C in progress, aligned by the
  enter stub; the code never pushes. `SYNC` writes the stack pointer (the
  frame's base plus its registers, plus what a primitive's arguments
  push), the pc after the instruction and the count to the VM before any
  call into C; `RELOAD` takes the stack, the frame and its registers back
  after one, since a call may move the stack and a raise the frame. A
  call into C takes the System V or the Windows convention (`ms_call`;
  the VM is argument 0). The allocation fast path is `vm_alloc`'s in
  line -- `--gc-stress` to the slow path, the room, the bump, the counts,
  the header -- and every store into an object goes through
  `ms_store_field`, where a collector's barrier goes. Slow paths (a fatal
  error, an allocation the fast path could not make) are emitted after
  the function's code. The stubs: `enter(vm, at)` saves the callee-saved
  registers, loads the VM's into the code's and jumps to `at`; `leave`
  restores them and returns what `rax` says. An emitter that names a
  register the frame has not, or a field the object just allocated has
  not, is a mistake of the VM's own, and the macro-assembler says so and
  stops, on every machine: the code it would have made faults only where
  the stray access leaves what is mapped (the first such mistake, a
  closure filled with one capture too many, read a register 1,553 slots
  up and ran on Linux, and crashed on Windows).
* **`compile.h`, `compile.c`**: the compiler. A scan of the function finds
  where instructions begin, which are targets of jumps (and of a
  `SWITCH`'s table, whose `JUMP`s are data, never run) and which end a
  run; every instruction is compiled (since M5; a `RESULT` after a call
  is a phantom, which the callee's `RET` does, and the instruction after
  it a target). Then each instruction's emitter, with a run's length
  added to the count where the run begins (docs/native.md, *Counting*),
  the slow paths, and the code copied into the region, which is one
  64 MB mapping, executable, made writable to add a function's code; the
  enter and leave stubs are at its start. A code object's entry is
  written last. The helpers native code calls: `jit_h_prim` (the
  primitive from the registers, `fastprim.h`'s way, or pushed and
  called), `jit_h_alloc`, `jit_h_ret` (the frame of the top level's
  `RET`, answering what the driver is to do next), `jit_h_fatal` (the
  loop's message), `jit_h_call` and `jit_h_tailcall` (a call through a
  closure), `jit_h_push_handler`, `jit_h_raise`, `jit_h_primpush`, and
  `jit_h_grow` and `jit_h_grow_frames` (the stack and the frames grown
  where a call finds no room).
* **`emit.c`**: the emitters, one per instruction, over the
  macro-assembler. `runeisa` writes `vm/new/jit_emit.h`, their
  prototypes, so that an instruction without one does not build, and
  `vm/new/jit_cases.h`, the walk that reads each instruction's operands as
  the loop reads them and calls its emitter; the flow, raises and handlers
  of each instruction are the tables of `regops.h`.

Calls, returns, handlers and `PRIMPUSH` in tier 1 (M5): a known call
(`CALLK`, `TAILCALLK`) is in line -- the room checked (a slow path grows
the stack, another the frames), the callee's registers made above the
frame from the caller's, the frame pushed with the address of the code
after the caller's `RESULT` as its `native_ret`, the callee's registers
made the code's own (`rbp`, `r14`), and its entry read from its code
object and jumped to, or, where it has none, the VM made exact for the
interpreter and handed back. A call through a closure (`CALL`,
`TAILCALL`) is in line too since M7: the closure checked, its function
found, the room made (a slow path grows the stack and starts the
instruction over; the frames are checked first, since their slow path
clobbers what was found), the registers made and the frame pushed, and
the entry read from the callee's code object. A known call whose callee
has code jumps straight into it (M7): a call to the function itself to
its entry's label, another's by `jmp rel32` to its address, the code's
placement being known before it is emitted; a function whose code jumps
into another's goes with it when that one is invalidated (`jit_depend`:
the callers are recorded at the jump, and `jit_invalidate` walks them),
rather than its code being patched. `RET` writes the value into the
register of the caller's `RESULT` -- which the frame records when it is
pushed (`Frame.result`), as the loop's `RET` reads it too -- pops the
frame, and jumps straight into the caller's code where the frame kept a
`native_ret`, else hands back to the interpreter; the frame of the top
level returns through `jit_h_ret`.
So a `RESULT` after a `CALL` or `CALLK` is passed over by every engine
and counted by none (compile.c, a phantom), where a `RESULT` after a
`PRIMPUSH` runs and takes the value the primitive left above the
registers. `PUSHHANDLER` records, beside the pc, the address of the
handler's code (`Handler.native`, `vm/vm.h`; NULL from the loop's and from
an image), so that a raise -- `RAISE` through `jit_h_raise`, a primitive's
through `jit_h_prim` -- lands in the handler's native code where it has
some, from the interpreter too (`RAISED` in the loop's words). `--trace`
runs the interpreter alone.

Made fast (M7): **the primitives of `fastprim.h` are in line**
(`prim_inline` in `emit.c`), each exactly what `prim_fast` gives and to
a slow path -- the helper, which does the primitive as the loop would
and may raise -- wherever `prim_fast` would answer 0 (a tag that is not
the one, an overflow, a divisor of 0 or -1, an index out of bounds);
`poly_eq` on a pointer or a real and `string_order` go to helpers that
touch nothing of the VM (`jit_h_values_equal`, `jit_h_string_order`),
called with nothing synced or reloaded, and `ref_new` is an allocation
in line. **A primitive not in line is called as the loop calls it:** its
arguments pushed above the registers, the VM exact, the primitive's own
C, the result it left on the stack taken; after a raise, on in the
handler's code where it has some, else the interpreter. **A comparison
and its branch are one:** the comparison leaves its bool in the flags
(`flags_for`), the count of a run is added with `lea`, which leaves the
flags alone, and a `JUMPIF` or `JUMPIFNOT` on that register right after
branches on them, with no tag test and no load; a comparison's slow path
puts the bool back into the flags. **Unit goes only where it is
needed:** a call fills the callee's registers from the lowest one not
provably written before the first instruction at which a collection
could see it or control could arrive from elsewhere (`jit_fill_from`,
from the generator's `rop_dest`, the operand an instruction writes;
little in practice, since a `PRIM` that may raise allocates). And
`--jit-stats` counts the calls of each primitive from code, most called
first, and `--jit-perf-map` writes `/tmp/perf-PID.map` for `perf record`.

Correctness is `--count`: the code counts every instruction the loop
would, allocates every object it would, and prints what it prints, which
`make test-new-jit` holds it to on every suite (`--jit=all`) and with
every other function compiled (`--jit-only=odd`), with the program of
every instruction, `tests/opt/prims.sml` on their edge cases and the
compiler compiling itself, `--gc-stress` and the sanitisers.

## Calls into C: the transition, and the FFI's

Native code calls into C in one way, wherever it does (`masm.c`, `ms_sync`,
`ms_call`, `ms_reload`), and this is the sequence a foreign function
call will take too (docs/plans/jit.md, *Prerequisites and flags*, the
FFI):

1. **`SYNC`:** the VM is made exact where C can look -- `vm->pc` the pc
   after the instruction (what a trace, an error and an image would
   name), `vm->sp` the frame's base plus its registers plus what the
   instruction has pushed, `vm->instructions` the count. `vm->fp` and
   the frames are always exact: the code keeps them in the VM, never in a
   register alone.
2. **The arguments:** the VM in argument 0, the rest in the convention's
   registers (`ms_arg`); a `Value` never crosses the ABI by value, only
   by its register number or a pointer, since the two conventions pass a
   16-byte struct differently.
3. **The call:** an absolute address in `rax` (the code and the runtime
   may be anywhere in the address space; Windows puts them far apart),
   the shadow space of the Windows convention reserved around it. The
   machine stack is aligned by the enter stub and holds nothing else.
4. **What C may do:** allocate and so collect (every register is a root,
   since every value is in its slot), grow the value stack (which moves
   it), push and pop frames, raise (which pops frames and handlers and
   leaves the handler's frame on top), change the program
   (`Runtime.restore`) or end the process. A helper that does none of
   these -- compares two strings, `values_equal` -- is called with
   nothing synced or reloaded (M7), and says so where it is declared. What it may not do is run
   bytecode: a helper never calls the loop or native code (no nesting;
   *The driver*), and a foreign function that calls back into SML is the
   one thing this sequence does not give (the FFI's decision, before M9).
5. **`RELOAD`:** the stack, the frame's base and its registers taken back
   from the VM. Nothing that pointed into the heap or the stack before
   the call is used after it; what the code needs it loads again from a
   slot.
6. **The answer:** a helper that may have changed what runs next (a
   raise into another frame's handler, a call, a primitive that made the
   program another) answers with where to go: an address to jump to, or
   a code the driver takes (`RUN_INTERP`, `RUN_NATIVE`, `RUN_HALT`)
   through the leave stub.

## Images

An image (`vm/image.c`) is in bytecode terms and shared with `runevm`, with
the register instruction set's fingerprint in its magic. The places a
program resumes at are the `RESULT` after a `PRIMPUSH` (`rt_save`,
`rt_restore`, `posix_fork`, which leave their result on the stack) and,
for each frame, the `RESULT` after its call. A resumed VM enters
`vm_loop`, which makes room for its frames first. The frames of an image
carry no native return address and its handlers no native code, so each
runs interpreted until it returns or is unwound, and what it calls runs
at its own tier; entering a resumed frame's code at its resume point is
the table of pc to address, M6. Under `--jit=all` `make test-new-jit`
holds `--restore`, `Runtime.restore` and the emulated fork to the
interpreter's output and counts.

## What is measured, and how

`runevm-new --count` counts instructions executed and bytes and objects
allocated, and `make perf-check` holds them to `tests/perf/new/*.budget`.
Cycles are `scripts/perf-cycles.sh` (docs/plans/jit.md, *Measuring*).
`make test-new-jit` (part of `make check`) runs `tests/lang` and the Basis
Library suite with every function given to the JIT (`--jit=all`), holds
every program of `tests/lang` and `tests/perf` and the primitives' edge
cases to the same output and `--count` in both modes and every
instruction to occurring in them (`scripts/check-jit.sh`), runs
`--jit-check`, and a recursion 200,000 deep under a machine stack of 1
MB; `make test-stress`, `make test-new-asan` and `make test-windows` run
the suites under the JIT as well.
`make test-new` (part of `make check`) runs `tests/lang` on it, holds every
program's allocation and the compiler's own output to `runevm`'s and the
primitives of `fastprim.h` to their edge cases (`scripts/check-new.sh`),
and runs the Basis Library suite; `make test-new-asan` and `make
test-stress` run `tests/lang` with the sanitisers and with a collection
every 101st allocation; `make test-windows` and `make test-portability`
run the suites on the other machines' builds.
