# runtime/register as built

The virtual machine for the register bytecode, as it is: enough, with the
sources it names, to build it again. Every change to `runtime/register` keeps this
current (`AGENTS.md`). What is planned for it is
[docs/plans/jit.md](../../docs/plans/jit.md); what a program can count on is
[docs/runtime.md](../../docs/runtime.md); the instruction set is described
in [docs/bytecode.md](../../docs/bytecode.md) and `src/isa/regs.sml`.

## What it is made of

`bin/runevm` is `runtime/main.c`, `runtime/register/interp.c`, `runtime/register/isa_regs.c`,
`runtime/register/live.c` (what is live where, for tier 2 and for the collector),
`runtime/register/jit.c` and the compiler in `runtime/register/jit/` linked against
`build/librune.a`, the runtime `runevm-stack` is built from
(`Makefile`, `bin/runevm`): the heap and collector (`runtime/heap.c`),
frames, handlers, raising and traces (`runtime/runtime.c`), the loader
(`runtime/loader.c`), the primitives (`runtime/prims.c`), images (`runtime/image.c`) and
the system layer (`runtime/sys/sys_*.c`). The archive also holds the stack
bytecode's part (`runtime/stack/isa_stack.c`); `runtime/register/isa_regs.c` is linked before
it and takes its place: the fingerprint an `.rbc` and an image carry, the
check of a program, the disassembler. The Windows, 32-bit and PowerPC
builds (`bin/runevm.exe`, `bin/runevm32.exe`, `bin/runevm32`,
`bin/runevm-ppc64`) and the sanitiser build are made from the same
sources with `runtime/stack/isa_stack.c` left out (`NEW_SRCS`, `WIN_NEW_SRCS`).

The generated files -- `runtime/register/regs.def`, `regops.h`, `reg_cases.h`,
`reg_labels.h`, `jit_emit.h`, `jit_cases.h` and `src/backend/regcodes.sml`
-- are written by `runeisa`
from `src/isa/regs.sml` (`make isa`; `make check-isa` fails when they are
stale) and committed, so that the VM builds with a C compiler alone.

## Values, objects and the heap

As `runevm-stack`'s ([docs/runtime.md](../../docs/runtime.md)): a `Value` is
one 64-bit word (`runtime/value.h`), an immediate where its low bit is set
-- an int, a word, a char or a tag as 2n + 1, or a real in its encoding --
and a pointer where it is clear, so that a value is made in one register
and stored in one store; a real outside the encoding and an `Int64.int` or
`Word64.word` past 63 bits are boxes of 8 raw bytes; objects have an 8-byte
header and a payload in multiples of 8;
the collector is a Cheney two-space copier that runs only inside
`vm_alloc`, with the value stack below `sp`, the globals, the constants,
each frame's closure and the built-in exceptions as its roots. There are
no stack maps and no write barrier: every slot is a word whose low bit
tells an immediate from a pointer. Of the stack, the registers of a frame
that waits for a call are roots as far as they are live there
(`VM.frame_live`, which `vm_loop` sets to `reg_frame_live` of `live.c`):
the collector asks with the frame's function and the pc its callee returns
to, gets the registers live at that instruction joined with what the
function's handlers need, and writes unit into a dead register that holds
a pointer, so that the frame, running again with all its registers roots,
has nothing that points into the space left behind. The answer for a
function is made from its code when first asked for -- the pcs its calls
return to and a word of 64 registers for each (`Function.live_pc`,
`live_at`) -- and goes with the program. The frame that runs keeps every
register, and so does a register past the 64th. The liveness is the one
tier 2 writes its homes back by, so an instruction's registers are its
operands, as the tables say (`reg_uses_defs`): one that read a register
its operands do not name would lose it at a collection. `-DRUNE_ROOTS_ALL`
builds a VM with every register a root, to measure against. The
stores into the heap are `SETENV`, the primitives `ref_set` and
`array_update` (in `runtime/prims.c`, and in the loop through `HEAP_STORE` of
`runtime/register/fastprim.h`) and a few more primitives; each is
`obj_set_field` (`runtime/value.h`), whose barrier is empty, and
`ms_barrier` in compiled code. The collector's state and the allocation
state are structs of the VM (`GcState`, `AllocState`, `runtime/vm.h`): the
fast path bumps `alloc.used` against `alloc.size`.

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

`runtime/register/interp.c` defines the words the bodies of `src/isa/regs.sml` are
written in and includes `runtime/register/reg_loop.h` twice, as `loop_fast` and as
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

`PRIM p d a...` first asks `prim_fast` (`runtime/register/fastprim.h`) to do the
primitive from the registers: the common case of the primitives `runeopt`
does in line -- the arithmetic and comparisons of ints, words, reals and
chars, `=` on values not in the heap, `!` and `:=`, the length and elements
of strings, vectors and arrays. It gives the result `runtime/prims.c` gives or
declines (an overflow, a divisor of zero or of `~1`, an index out of
bounds, an argument of the wrong kind), and then the arguments are pushed,
the VM made exact, the primitive called and its result popped, or its
raise taken. Either way a `PRIM` counts one.

## The driver and the JIT's view of a program

`vm_loop` is a driver (`runtime/register/jit.h`): it runs whatever frame is on top
at that frame's tier -- the interpreter's, or the native code the JIT
made -- and no engine calls another. The interpreter hands the VM back
to the driver, exact, when the function it is about to enter has a
native entry (`HANDOVER` in `CALL`, `CALLK`, `TAILCALL` and `TAILCALLK`)
and when a `RET` lands in a frame whose caller left a native return
address (`RETURN_NATIVE`); native code hands it back when it must run an
interpreted frame or returns into one. So the machine stack is one C
frame deep whatever the program does, plus the call into C in progress:
`make test-register-jit` runs a recursion 200,000 deep under a machine stack
of 1 MB with every function handed to the JIT. That is what lets frames
be switched (green threads), copied (continuations) and rebuilt
(deoptimisation) later.

The JIT's view of the program (`JitProgram`, made by `jit_program` when
the driver first sees a program and again when it becomes another,
`Runtime.restore`) is a code object per function: its entry, NULL while
it is interpreted; its tier; the counters tier 0 keeps for the tiering
policy; and its code's table of pc to address. An entry is published
last, with one store. `--jit=off` runs the interpreter alone, `--jit=all`
gives every function an entry at load, `--jit=baseline` compiles a
function at tier 1 when its counters say so, `--jit=opt` (the default
since M10) at tier 2 (M9);
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
`sys_code_free`; `runtime/sys/sys.h`), writes a few bytes of this machine's code
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

`runtime/register/jit/` compiles a function of the register bytecode to x86-64
machine code (docs/plans/jit.md, D3 and M4): one instruction at a time,
in the order of the bytecode, each doing what its case in the loop does,
in the same frame, with every value in its slot. It is `runeopt`'s
contract (docs/native.md) for the register bytecode, at run time, in C.

* **`x64.h`, `x64.c`**: the encoder. A buffer of bytes, labels bound and
  patched (a rel32 to a label, or a table entry relative to a table's
  start), and the instructions the macro-assembler is written in: moves,
  8-byte copies through an xmm register, arithmetic, SSE2 on doubles,
  branches, calls. Nothing here knows a Value or a VM. Where the
  machine has a shorter form for what is asked, the encoder gives it:
  a move of an immediate that 32 bits hold is the move to the low half,
  a test of bits the low byte has is a test of that byte (a tag's test
  is two to four bytes, not seven), a multiplication by a small
  constant has it in a byte.
* **`masm.h`, `masm.c`**: the macro-assembler, and the conventions the
  code keeps. `r13` is the VM (`r12` would make every memory operand
  based on it a byte longer), `rbp` the frame's base as an index into
  the value stack, `r14` its registers (the stack plus `8 rbp`), `r15`
  the count of instructions; register k is the 8 bytes at `[r14 + 8 k]`.
  The stack itself has no register: what moves between frames reads it
  from the VM. The fields of the VM that the code names most are the
  VM's first 128 bytes (`vm.h`), where an offset is one byte of an
  instruction and not four. The
  machine stack holds only the call into C in progress, aligned by the
  enter stub; the code never pushes. `SYNC` writes the stack pointer (the
  frame's base plus its registers, plus what a primitive's arguments
  push), the pc after the instruction and the count to the VM before any
  call into C; `RELOAD` takes the stack, the frame and its registers back
  after one, since a call may move the stack and a raise the frame. A
  call into C takes the System V or the Windows convention (`ms_call`;
  the VM is argument 0). The allocation fast path is `vm_alloc`'s in
  line -- `--gc-stress` to the slow path, the room, the bump, the counts,
  the header -- and a store into an object that exists (`ref_set`,
  `array_update`, `SETENV`) is followed by `ms_barrier`, the barrier's
  place in compiled code, which emits nothing today and a card mark in
  the VM built to measure one (`bin/runevm-cards`); a fill of a fresh
  object is `ms_store_field` alone. A kind is tested by `kind_is`: the
  header's first byte compared whole, as `obj_kind` reads it in C, since
  the four bits it shares with the kind are the collector's and zero;
  both take the kind's bits alone in the VM whose collector sets the
  others (`bin/runevm-gcbits`, `RUNE_GC_BITS`). The arrays of bytes and
  of reals are in line as strings and arrays are (`bytes_length`,
  `bytes_sub`, `bytes_update`, `reals_length`, `reals_sub`,
  `reals_update`): an element of an array of reals is loaded into a
  home and stored from one as the double it is, no word between. An
  int as a real and a real as an int are in line too (`int_to_real`,
  `real_abs`, `real_trunc`, `real_floor`, `real_ceil`): one conversion,
  with the primitive for what an int does not hold and for a NaN. Slow paths (a fatal
  error, an allocation the fast path could not make) are emitted after
  the function's code. A fatal error -- the check of something the
  bytecode should guarantee, which a typed program never fails -- is
  ten bytes there: the number of a record of what its message says in
  `rax`, and a jump to the stub of fatal errors at the region's start
  (`ms_emit_fatal`), which tells `jit_h_fatal_at`. The message and the
  trace read the pc, which the record has, and the frames, which are
  exact; nothing is written back (each was a sync and a call of its
  own, a fifth of the compiler's code). The stubs: `enter(vm, at)` saves the callee-saved
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
  64 MB mapping, executable, made writable to add a function's code. At
  its start (`jit_region_init`) are the enter and leave stubs, the stub
  of fatal errors and a trampoline for every call into C the code makes
  -- every primitive and every helper -- where a function anywhere in
  the region reaches them by a direct jump or call (`ms_call`,
  `ms_handback`; `placed` in the masm says the code knows where it will
  run). A code object's entry is
  written last. The helpers native code calls: `jit_h_prim` (the
  primitive from the registers, `fastprim.h`'s way, or pushed and
  called), `jit_h_alloc`, `jit_h_ret` (the frame of the top level's
  `RET`, answering what the driver is to do next), `jit_h_fatal_at` (the
  loop's message, from the stub), `jit_h_call` and `jit_h_tailcall` (a call through a
  closure), `jit_h_push_handler`, `jit_h_raise`, `jit_h_primpush`, and
  `jit_h_grow` and `jit_h_grow_frames` (the stack and the frames grown
  where a call finds no room).
* **`emit.c`**: the emitters, one per instruction, over the
  macro-assembler. `runeisa` writes `runtime/register/jit_emit.h`, their
  prototypes, so that an instruction without one does not build, and
  `runtime/register/jit_cases.h`, the walk that reads each instruction's operands as
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
handler's code (`Handler.native`, `runtime/vm.h`; NULL from the loop's and from
an image), so that a raise -- `RAISE` through `jit_h_raise`, a primitive's
through `jit_h_prim` -- lands in the handler's native code where it has
some, from the interpreter too (`RAISED` in the loop's words). `--trace`
runs the interpreter alone.

Made fast (M7): **the primitives of `fastprim.h` are in line**
(`prim_inline` in `emit.c`), each exactly what `prim_fast` gives and to
a slow path -- the helper, which does the primitive as the loop would
and may raise -- wherever `prim_fast` would answer 0 (a tag that is not
the one, an overflow, a divisor of 0 or -1, an index out of bounds);
`string_order` goes to `jit_h_string_order`, which touches nothing of the
VM and is called with nothing synced or reloaded. `poly_eq` on a pointer
or a real calls `jit_h_values_equal` with the VM exact and reloaded after:
structural equality can end the process at its work limit. `ref_new` is an allocation
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
`make test-register-jit` holds it to on every suite (`--jit=all`) and with
every other function compiled (`--jit-only=odd`), with the program of
every instruction, `tests/opt/prims.sml` on their edge cases and the
compiler compiling itself, `--gc-stress` and the sanitisers.

## Tier 2: the registers given homes

Tier 2 (docs/plans/jit.md, M9) is tier 1's code with the values of some
of the frame's registers kept in machine registers -- their *homes* --
for the whole of the function, rather than in their tagged slots. The
roadmap planned an SSA form and a linear scan here; what the bytecode
brings since M8 made that redundant: the compiler's `Regs` has already
allocated the function's registers by liveness, within a representation
class, and the representations section says what each register holds.
So tier 2 takes the registers as they are and chooses, per function,
which of them live in a machine register:

* **Which.** A register whose representation a machine register can
  hold -- an int, a word, a char, a nullary constructor, an `Int64.int`
  or a `Word64.word` in one of six general registers (`rbx`, `r12`,
  `rsi`, `rdi`, `r10`, `r9`; `as_home_g`, `asm.h`), a real in `xmm2`
  to `xmm15` -- the most used first, a use inside a loop (the section's
  loop heads to the last jump back) counting for eight, and a number
  that is raw in its home for four more (`choose_homes`, `compile.c`).
  aarch64 has twelve general homes and thirty for reals.
* **Not for nothing.** A register live across a call of a function is
  written to its slot before the call and loaded again after it: a
  store and a load, where each use of the home saved one of the two --
  and for a raw home an encoding and a decoding. So a register has a
  home only where its uses outweigh the calls it is live across, twice
  over for a word and six times for a raw one (`HOME_CALL`,
  `HOME_CALL_RAW`), a call in a loop weighing eight as a use there
  does. Measured, not derived: `barnes-hut` ran in 0.83 of the
  instructions for it, the compiler in 0.998.
* **What C keeps.** `as_keeps_g` and `as_keeps_f` say which registers
  a call into C leaves as they were, by the machine and its convention
  (Linux on x86-64: `rbx`, `rbp`, `r12` to `r15` and no register of
  reals; Windows: `rsi`, `rdi` and `xmm6` to `xmm15` too; aarch64:
  `x19` to `x28` and the doubles of `v8` to `v15`). The homes are
  given out with those first, so the order differs by convention
  (Windows's reals start at `xmm6`), and a home C keeps is not saved
  around the helper that boxes a number nor loaded again after a call
  into C -- unless it is the register the instruction defines, whose
  slot the helper may have written (`ms_reload`, `ms_reload_clobbered`,
  `ms_emit_box`).
  The emitters keep the other general registers as scratch and for the
  arguments of calls into C; `r9` and `r10` are scratch too, but only
  in a call's or a return's sequence after it has read its last home
  (`emit.c`). A pointer never has a home: the collector's roots are
  the slots, as at tier 1.
* **Shared.** Two registers have one home where they are never live
  together. They interfere where both are live at the entry of an
  instruction, and where an instruction defines one while the other is
  live at its entry; each register, in the order above, takes the
  first home that no register it interferes with has. The register an
  instruction defines so never has the home of one it reads, and an
  emitter may write it before it has read them all. What is in a home
  is then its register's only while that register is live: the
  write-back and the loading go by what is live at a pc, as before,
  and the loading after a call into C in the middle of an instruction
  takes the registers live at its entry first and then the one it
  defines (`ms_reload`, `masm.c`). `--jit-stats` says how many of the
  registers that could have a home have one, and what share of their
  uses one home, two, three and so on would hold: a register that gets
  none is numbered on past the homes there are, so the line answers
  what another home would be worth before it is found a register.
* **Constants.** A real's constant goes to its home as the double, and
  an `Int64.int`'s or a `Word64.word`'s as its 64 bits, made when the
  function is compiled: a constant past 63 bits is a box, and nothing
  reads it while the code runs (`emit_CONST`).
  The home of an int, a word, a char or a tag holds its word, as the
  slot does. The home of a real, of an `Int64.int` and of a
  `Word64.word` is *raw*: the double, or the 64 bits themselves, which
  for a number past 63 bits no word has -- its slot gets the word, or
  a box, where the value leaves the register (`Home`, `masm.h`;
  `is_raw`, `masm.c`).
* **The accessors know.** Every operation of the macro-assembler that
  reads or writes a register (`ms_copy`, `ms_set`, `ms_load_payload`,
  `ms_check_tag`, `ms_store_field`, `ms_value_to`, ...) consults the
  homes, so the emitters are tier 1's, unchanged: a tag test of a homed
  register is decided when the code is made (the tag is the
  representation's), and the slot of a raw home is given its word where
  the word is wanted (`ms_need_word`, a `RET`).
* **Liveness.** The registers live at the entry of each instruction are
  computed backwards over the function (`liveness`), the handlers of the
  function being successors of every instruction that may raise or call
  -- at the instruction's entry, since a raise happens before it defines
  anything.
* **Safepoints.** `ms_sync` writes the homes live at the instruction's
  entry back to their slots -- a raw one encoded, or boxed by a helper
  where it has no immediate -- before the VM is made exact; `ms_reload` loads again, after the call into C, the homes live
  at the entry and at the end of the instruction (C may have written the
  slot of the register the instruction defines, and clobbered `rsi`,
  `rdi` and the xmm registers). A helper that touches nothing of the VM
  (`ms_call_lean`) still clobbers the homes, so the emitter writes them
  back before it sets the arguments -- the arguments' registers are
  homes -- and the call loads them again. The slow path that grows the
  stack and starts the instruction over keeps its argument in `r11`
  across the write-back for the same reason.
* **Calls.** A `CALL`, `CALLK` or `TAILCALL` writes the homes back
  first: the callee has the machine registers, and what is live after
  the call is loaded again at its *landing*.
* **Landings.** Wherever code is entered from outside -- the entry,
  the instruction after a call, a handler, the loop heads and run starts
  the interpreter enters mid-way (`jit_osr`) -- a landing loads the homes
  live there and goes on to the instruction's label (`jit_landing`);
  the entry's landing loads the parameters' homes, and a call to the
  function itself jumps to it. Jumps within the function go to the
  labels, since the homes are the function's throughout. The OSR table,
  a handler's `native` and a frame's `native_ret` hold landings.
* **Windows.** The convention there has C keep `xmm6` to `xmm15`, which
  the homes use, so the enter stub saves them and the leave stub restores
  them (160 bytes below its pushes).

Tier 2 also **trusts the section for the shape of a value** (M10): a
register the section says holds a pointer holds a pointer to an object
of the kind the instruction expects, and a tuple or a constructor has
the field the instruction names, so the tag, kind and length tests the
loop and tier 1 make are left out (`ms_trusts`, `ms_load_obj`; a
`SELECT` or `FIELD` on a trusted register is a load; a datatype value
that is not nullary is a pointer to a constructor,
`ms_load_tag_of_con`), and `=` on two
values of one immediate representation compares the payloads alone
(`ms_immediate`). The loader's lint holds a program to its section; a
program that lies to it runs wrongly at tier 2 where the interpreter
and tier 1 would have stopped it. **A function's code fills its own
registers with unit** at its entry (M10), from its arity up
(`jit_fill_from` says from where), so a call to a function with an
arity in the section does not; a caller fills for a callee without one,
and for the interpreter where the callee has no code (`fill_unit`,
`fill_unit_dynamic`; `jit->all_meta` says every function has an
arity). `Math.sqrt` is in line (`sqrtsd`).

`--jit=opt`, the default since M10, compiles at tier 2 what
`--jit=baseline` would at tier 1, by the same counters; `--jit-tier=N` fixes the tier under any mode, so
`--jit=all --jit-tier=2` is every function at tier 2 (the oracle's fifth
mode, and its sixth every other function, so that tiers 1 and 2 call and
raise into each other); `--jit-stats` says how many were compiled at
tier 2, and the perf map names them `jit2:NAME`. A function whose
registers give no home is compiled as tier 1's code. The counts of
`--count` are unchanged by construction: the code is tier 1's, and the
run counting with it.

## Deoptimisation: leaving the code (M11)

The roadmap planned maps from machine registers to the interpreter's
at every safepoint, and inline frames made VM frames again. The design
as built needs neither: tier 2 has no inlining, and at every safepoint
the frame is the interpreter's -- the slots hold every value as its
word (the homes written back), the VM its stack pointer, pc and count.
So leaving the code for the interpreter -- an *OSR exit*, the
deoptimisation this JIT has -- is a jump to the leave stub with
`RUN_INTERP` and the pc to go on at, which the code did for a callee
without code, a return into a frame without `native_ret` and a raise
into a handler without `native` since M5, and which invalidation with
frames live relies on since M6 (`jit_invalidate` walks the frames and
handlers, and a frame returning into code that is gone returns to the
interpreter; `--jit-stress=N` tests that at every Nth call).

What M11 adds is the exit at an arbitrary *instruction boundary*
(`ms_exit`): after an instruction whose effects are complete and whose
successor is the next -- not a branch, a call, a return, a raise, nor a
`PRIMPUSH`, whose `RESULT` takes its value from the stack -- and not
between a comparison and the branch fused onto it, the homes live at
the boundary are written back, the VM made exact, and the count of the
run, which was added at the run's start for all of its instructions,
reduced by the instructions of the run the interpreter will now count
itself, so that `--count` stays exact. `--deopt-stress=N` makes the
code leave at every Nth such boundary (a counter in the code, a slow
path per boundary): the oracle runs every program with `N = 1`, the
code leaving after every instruction it enters, and the compiler
compiling itself with `N = 7`, and holds both to the interpreter's
output and counts. `--jit-stats` counts the exits (`left mid-way`).
Speculation without a fallback, which would need a deoptimisation with
a reason, was not built: M10 found no site where it would pay.

## The targets: what a machine must provide (M12)

The emitters, the macro-assembler and the compiler are written over the
*portable assembler* (`runtime/register/jit/asm.h`) alone -- `make test-register-jit`
holds them to naming no encoder -- and a target is one implementation
of it over its encoder: x86-64 in `asm_x64.c` over `x64.c`, aarch64 in
`asm_a64.c` over `a64.c` (each encoder tested against the bytes
`llvm-mc` gives, `tests/register/x64_test.c` and `a64_test.c`). What the
implementation gives:

* **The registers**, under the portable names: the four the code keeps
  (`R_VM`, `R_BASEI`, `R_BASER`, `R_COUNT`), seven scratch registers
  (`R_S0`, the return value of a call into C, to `R_S6`) and two
  floating (`F_S0`, `F_S1`); and tier 2's homes, which have no names
  but a table by the convention of the calls into C: `as_home_g` and
  `as_home_f` give the kth, `as_keeps_g` and `as_keeps_f` say what a
  call into C keeps. x86-64 keeps `r13`, `rbp`, `r14`, `r15`; its
  homes are `rbx`, `r12`, `rsi`, `rdi`, `r10`, `r9` and `xmm2` to
  `xmm15` (on Windows from `xmm6`); its scratch `rax`, `rcx`, `rdx`,
  `r8` to `r11`, `xmm0`, `xmm1` -- sixteen registers for seventeen
  roles, so `R_S4` and `R_S5` are the last two homes, and an emitter
  names them (and `R_H1`, `R_H2`: `rsi`, `rdi`) as scratch only where
  no home is live any more. aarch64 keeps `x19`, `x21` to `x23`; its
  homes are `x24` to `x26`, `x20`, `x28`, `x27`, then `x15` and `x4`
  to `x8`, and `v8` to `v31`, then `v2` to `v7`; its scratch `x0`,
  `x9` to `x14`, `v0`, `v1`, with `x16` the encoder's own and `x17`
  the assembler's. The VM has a cell for each of the machine's
  registers, by its number, where a home waits across the helper that
  boxes (`jit_gspill`, `jit_fspill`).
* **The operations**, with x86-64's meanings where the machines differ:
  `add`, `sub`, `cmp`, `test` and `neg` set the flags a `jcc` or `setcc`
  reads, and nothing else promises to (an emitter that wants the sign
  of an `xor` tests it); a multiply that may overflow is one operation
  with its jump (`as_mul_jo`: `imul` and `jo`, or `mul`, `smulh` and a
  compare); a divide gives the quotient in `R_S0` and the remainder in
  `R_S2` (`cqo` and `idiv`, or `sdiv` and `msub`); a shift by a
  register takes the count in `R_S1`; a comparison of reals is read
  by `CC_FA`, `CC_FAE` and `CC_FE`, which are false on a NaN on every
  target (`ja` and `jae` after `ucomisd`, and `setcc` with the parity
  bit for equality; `gt`, `ge` and `eq` after `fcmp`); a memory operand
  is `[base + disp]`, or with an index for `lea` and the 16-byte moves,
  and the aarch64 side puts an offset or an immediate the instruction
  cannot hold in its own register first; a push moves the stack by 16
  on both, so it stays aligned; a table of 32-bit offsets is jumped
  through the same way (`as_ld32sx`).
* **The conventions**: the enter stub's saving of what C keeps and its
  taking of the VM and the address to go to (`as_stub_enter`), the
  leave stub (`as_stub_leave`), the register of the i-th argument of
  a call into C (`as_arg`) and the call (`as_call_c`: through `rax`
  with the Windows shadow space, or `blr x16`); the trampoline
  (`as_trampoline`: the VM moved into argument 0, then a jump through
  the helper's address beside it, or on Windows the shadow space made
  and the call), which compiled code calls directly (`as_call_to`: a
  `call rel32`, five bytes, or a `bl`), where the long way was fifteen
  bytes, twenty-three on Windows, and five or six instructions on
  aarch64. On aarch64 every general home is a callee-saved register,
  so a call into C keeps it: the code writes it back where a sync
  wants the slot exact, and does not load it again (`as_keeps_g`).
* **The system**: executable memory and the instruction-cache flush
  (`sys_code_flush`, `__builtin___clear_cache`, which x86-64 needs not).

`bin/runevm-aarch64` is the register VM built for aarch64 with its
JIT (`make portability`, clang with the arm64 cross packages, run by
`qemu-aarch64`); `make test-portability` runs `tests/lang`, the Basis
suite and the JIT's oracle on it, so every mode of the JIT is held to
the interpreter's output and counts on the second target as on the
first.

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
3. **The call:** a direct call of the helper's trampoline at the start
   of the region, which puts the VM in argument 0 and goes on through
   the helper's absolute address (the code and the runtime may be
   anywhere in the address space; Windows puts them far apart), the
   shadow space of the Windows convention reserved around the call; a
   helper without one, the same in line (`as_call_c`). The machine
   stack is aligned by the enter stub and holds nothing else.
4. **What C may do:** allocate and so collect (every register of the
   frame that runs is a root, since every value is in its slot), grow the value stack (which moves
   it), push and pop frames, raise (which pops frames and handlers and
   leaves the handler's frame on top), change the program
   (`Runtime.restore`) or end the process. A helper that does none of
   these -- compares two strings -- is called with
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

## What the compiler says beside the code

The register bytecode's representations section (docs/bytecode.md; the
compiler-runtime contract of docs/plans/jit.md, M8) says, per function,
its arity, what each register holds -- one representation per register,
since the compiler shares a register only among values of one -- its
blocks with their parameters' registers, and its loop heads; the loader
(`runtime/loader.c`) reads it into the `Function`, the register set's checker
(`runtime/register/isa_regs.c`) holds it to the code, an image carries it. Tier 1
reads none of it; tier 2 (M9) is its reader: a register whose
representation is an int, a word or a real can live in a machine register
without a tag test, one in the heap can be dereferenced without a kind
test, and the blocks and loops give the control-flow graph back.

## Images

An image (`runtime/image.c`) is in bytecode terms and shared with `runevm-stack`, with
the register instruction set's fingerprint in its magic. The places a
program resumes at are the `RESULT` after a `PRIMPUSH` (`rt_save`,
`rt_restore`, `posix_fork`, which leave their result on the stack) and,
for each frame, the `RESULT` after its call. A resumed VM enters
`vm_loop`, which makes room for its frames first. The frames of an image
carry no native return address and its handlers no native code, so each
runs interpreted until it returns or is unwound, and what it calls runs
at its own tier; entering a resumed frame's code at its resume point is
the table of pc to address, M6. Under `--jit=all` `make test-register-jit`
holds `--restore`, `Runtime.restore` and the emulated fork to the
interpreter's output and counts.

## What is measured, and how

`runevm --count` counts instructions executed and bytes and objects
allocated, and `make perf-check` holds them to `tests/perf/new/*.budget`.
Cycles are `scripts/perf-cycles.sh` (docs/plans/jit.md, *Measuring*).
`make test-register-jit` (part of `make check`) runs `tests/lang` and the Basis
Library suite with every function given to the JIT (`--jit=all`), holds
every program of `tests/lang` and `tests/perf` and the primitives' edge
cases to the same output and `--count` in both modes and every
instruction to occurring in them (`scripts/check-jit.sh`), runs
`--jit-check`, and a recursion 200,000 deep under a machine stack of 1
MB; `make test-stress`, `make test-register-asan` and `make test-windows` run
the suites under the JIT as well.
`make test-register` (part of `make check`) runs `tests/lang` on it, holds every
program's allocation and the compiler's own output to `runevm-stack`'s and the
primitives of `fastprim.h` to their edge cases (`scripts/check-register.sh`),
and runs the Basis Library suite; `make test-register-asan` and `make
test-stress` run `tests/lang` with the sanitisers and with a collection
every 101st allocation; `make test-windows` and `make test-portability`
run the suites on the other machines' builds.
