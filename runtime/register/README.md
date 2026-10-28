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
`reg_labels.h`, `jit_emit.h`, `jit_cases.h` and `lib/compiler/backend/regcodes.sml`
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
the collector is generational, a nursery that a minor collection copies
out of and an old space that a full one copies (`runtime/gc/`), and runs
only inside `vm_alloc`, with the value stack below `sp`, the globals, the
constants, each frame's closure and the built-in exceptions as its roots,
and for a minor collection the cards the barrier marked. There are no
stack maps: every slot is a word whose low bit tells an immediate from a
pointer. Of the stack, the registers of a frame
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
register where the interpreter runs it; where compiled code does, the code
said which are live at the call into C it made (`VM.top_live`, at every
sync; the driver forgets it when the code hands back), and the frame is
taken as one that waits -- since M6 of docs/plans/performance.md a frame's
registers are not filled with unit, and one not written yet may hold what
an earlier frame there left. A register past the 64th is a root. The liveness is the one
tier 2 writes its homes back by, so an instruction's registers are its
operands, as the tables say (`reg_uses_defs`): one that read a register
its operands do not name would lose it at a collection. `-DRUNE_ROOTS_ALL`
builds a VM with every register a root, to measure against. The
stores into the heap are `SETENV`, the primitives `ref_set` and
`array_update` (in `runtime/prims.c`, and in the loop through `HEAP_STORE` of
`runtime/register/fastprim.h`) and a few more primitives; each is
`obj_set_field` (`runtime/value.h`), whose barrier (`gc_barrier`,
`runtime/vm.h`) marks the card of an old object's field given a pointer
into the nursery, and `ms_set_field` or `ms_set_element` in compiled
code. The collector's state and the allocation
state are structs of the VM (`GcState`, `AllocState`, `runtime/vm.h`): the
fast path bumps `alloc.used` against `alloc.size` -- in compiled code a
pointer in a register of its own against `VM.alloc_limit`, below.

## Frames, registers and the stack

A frame lives in the value stack (docs/plans/native-frames.md, M4): its
registers from its base, and below them a header of three words its
caller writes (`isa_regs.c`, `regvm.h`) -- the *info word*, an immediate
of the caller's function and the pc of the `RESULT` the call returns to;
the closure the frame runs in, where it was called through one, else
`unit` or what the slot held; and the *return word*, where compiled
code's `RET` goes, an odd number and so an immediate to the collector: the
interpreter's return stub (`VM.ret_word`; 1 before the JIT's region
exists) or the landing of a call in the caller's compiled code. The
interpreter and the runtime write all three; compiled code writes the
return word, and the closure for a call through one or to a function that
reads its closure (`Function.reads_closure`: `ENV`, `SELF`), whose closure
is then `unit`. A frame's caller's registers end where its header
begins (a frame `vm_frame_push` makes above values of its own, the
debugger's `<debug>`, keeps its caller's base in a fourth word below), the
top level's frame says it has no caller -- and stays when the program
ends, its `RET` leaving the value above the header, for what walks the
frames after the end (the census's last collection) -- and the frame's
size is its registers and three. `VM.fp` is the running frame's base,
which names it (an id that grows with the depth), and `VM.func` its
function: the loop keeps both, compiled code tells them at a sync. The
handlers `{pc, func, sp, fp, native}` are an array of their own, `fp` the
handler's frame's base. The stack and the handlers grow by doubling
(`realloc`), which moves the value stack. The rest of the runtime reads
frames through the walk this instruction set gives (`vm.h`, *The frames,
as the runtime reads them*): the running frame from the VM, and each
frame's caller from its header -- the info word where the return word
is the interpreter's, else the landing's code object, which says the
caller's function and pc for each of its landings (`jit_landing_info`:
the code by address among the region's code objects, the landing by its
offset, the last 256 return words asked kept, with how far below the
frame the caller's base is). The walks of the collections and of the
barrier (`vm_frames_from`, `reg_barrier_pass`) step down without a call:
a return word one of the two they met last, as a deep recursion's frames
are, or one of the 256, is read in line. Of a header the collector scans
the closure alone, made `unit` where the frame's function does not read
one, so that it keeps nothing alive, and makes `unit` the info word of a
frame compiled code called, which does not write it, where the slot
holds a pointer from before (`FrameRef.stale_slot`, `GC_BELOW_FRAME` in
`gc/gc.h`); an image keeps the layout of every engine, without the
headers, which the writer leaves out and the reader makes
(`vm_frames_install`), so that images cross between the engines of this
instruction set and its builds before M4.

A function's registers are its slots on the value stack from its frame's
base, `nlocals` of them (the function table; the last is the scratch
register the compiler uses for a value nothing reads). The loop's calls
make them `unit`, compiled code's take them as the stack's *clean part*
has them (below), and a register no longer used still holds a value,
which the collector sees. Above the registers a frame pushes only the arguments of
a primitive, the value a call returns and the exception a raise leaves
for `CATCH`: the checker works out how deep that goes for each function
(`maxstack`: the arity of its widest `PRIM` or `PRIMPUSH`, or 1), a call
makes room for `nlocals + maxstack` (`ROOM`), and a push does not check.
`make_room` does the same for the frames of an image or of `vm_start`.

**The stack's clean part** (docs/plans/performance.md, M6; `VM.stack_clean`):
the slots from the stack pointer up to it hold `unit`, or a value
written since the last collection -- never what a collection left behind
-- so a frame compiled code makes there needs no `unit` in its
registers, every one being a root as it is. Compiled code's room checks
claim from it, comparing an address with its end's less `ROOM_SLACK`
values (`VM.stack_room`, `vm_room`): a known call whose frame, header
and room want no more compares its own frame's base, `r14`, and others
that base plus the rest (native-frames.md, M4). Their slow path claims
more (`vm_claim_stack`: the stack grown, the slots made `unit`,
`CLEAN_AHEAD` past what is wanted, and the slack past the compared
address at least); every collection makes the slots above the stack
pointer `unit` and keeps claimed no more than `CLEAN_AHEAD` of them
(`vm_clean_stack`), and an image's stack is clean to its pointer. The
clean part is the calls' poll too: the user's interrupt and the
debugger's make `VM.stack_room` 0 (`sys_interrupt_limit`,
`vm_poll_soon`), so that the next room check goes to its slow path,
which claims and then looks at `VM.interrupt`.

Calls: `CALL f x` and `CALLK f n a...` push a frame whose header begins
at the caller's stack pointer, make the callee's registers above it (the
argument, or the `n` arguments, then `unit`) and enter its code;
`TAILCALL` and `TAILCALLK` replace the frame, its header's caller and
return kept and its closure the callee's, the arguments copied above the
frame first and moved down. `RET s` pops the frame as its header says --
into the interpreter's caller at the pc its info word gives, or, where
the return word is a landing of compiled code, handing the VM to the
driver with the value (`VM.ret_value`), which enters the landing --
lowers the stack's watermark, below which a minor collection does not
scan, to the frame that runs again, and, since the caller goes on at a
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
count of instructions, the frame's registers (`base`) and the stack
pointer (`sp`), and in the VM, exact throughout, the frame's base and
function (`VM.fp`, `VM.func`):

* `R(x)` is register `x`; `LIST(i)` the `i`-th register of the
  instruction's list; `PUSH`, `POP` push and pop above the registers,
  unchecked;
* `SYNC()` writes `sp`, the pc and the count to the VM, before anything
  that reads them there: the collector (every allocation), a raise, a
  primitive, `vm_push_handler`, a fatal error; `RELOAD()` reads back the
  code, the pc, `base` and `sp` after anything that may have
  changed them or moved the stack; `ROOM(top, fn)` makes room for a frame
  of `fn` at `top`, and reloads `base` and `sp` if the stack moved;
  `HEADER(top, pc, closure)` writes the header of a frame whose registers
  begin at `top`, and `CLOSURE()` is the running frame's closure in its
  own;
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
and when a `RET` lands in a frame whose function has code, which goes on
at the place a run begins after its call (`RESUME_NATIVE`); native code
hands it back when it must run an interpreted frame or returns into one. So the machine stack is one C
frame deep whatever the program does, plus the call into C in progress:
`make test-register-jit` runs a recursion 200,000 deep under a machine stack
of 1 MB with every function handed to the JIT. That is what lets frames
be switched (green threads), copied (continuations) and rebuilt
(deoptimisation) later.

The JIT's view of the program (`JitProgram`, made by `jit_program` when
the driver first sees a program and again when it becomes another,
`Runtime.restore`, or grows, `Runtime.link`) is a code object per function: its entry, NULL while
it is interpreted; its tier; the counters tier 0 keeps for the tiering
policy; and its code's table of pc to address. An entry is published
last, with one store. `--jit=off` runs the interpreter alone, `--jit=all`
gives every function an entry at load, `--jit=baseline` compiles a
function at tier 1 when its counters say so, `--jit=opt` (the default
since M10) at tier 2 (M9);
`--jit-stats` prints at exit what the JIT did.

**Tiering (M6).** Tier 0 counts, per function, its calls (in
`HANDOVER`, at every call) and its work -- the iterations of its loops
(in `BACKWARD`, at every `JUMP` back), and its calls again (in
`HANDOVER`, whose frame on top is the function called) -- and compiles
the function at the threshold (`--jit-calls=N`, `--jit-work=N`; the
defaults are the sweep's, docs/plans/jit.md M6). The work counts for a
function called once that runs long in a loop: a driver loop, or the
compiler's passes; its code is entered at the loop's head. (This said
before that the work counted the calls a function makes, for the caller,
as the code's comment meant; counting the caller's work so was measured
in native-frames.md, *M8*: more functions compiled, 0.6% more
instructions on the bootstrap and 0.2% on HOL's kernel work, and the
code kept as it is.) The counters are instruction-based, so
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
counters and frees its tables, and walks the VM's frames and handlers:
a frame whose return word is a landing in the function's code is given
the interpreter's, and its info word the caller's function and pc from
the code's landings (`reg_frames_to_interpreter`), and every
`Handler.native` in the code becomes NULL, so that a return or a raise
into it goes to the interpreter, which goes on from that pc or the
handler's. That is
the whole of it, because the frames are the VM's (D4) and because no
native code is on the machine stack while the interpreter runs (the
driver's protocol): invalidation is only ever called from tier 0. The
code's bytes stay in the region (dead bytes, counted by `--jit-stats`;
reclaiming them is a later concern).

**A program that grows.** `Runtime.link` appends a unit's functions to the
program (`runtime/loader.c`, `load_unit_mem`; docs/units.md), which the
JIT's tables, indexed by function, are too short for. The primitive is a
`PRIMPUSH` that says `PRIM_NEW_WORLD` once its result is pushed, which the
loop and compiled code answer as they do for `Runtime.restore`: the VM is
handed to the driver, which asks `jit_program` for the view again. Where
the program is the same one grown (`VM.prog_epoch`, a new number for each
program read, the same while units are loaded), `jit_grow` extends the
code objects, the fills, the table of calls and the names and keeps all
the code: compiled code never holds the address of a table that grows --
a call loads the table of calls from the VM (`VM.jit_calls`), and
`fill_unit_dynamic` the fills' from the JitProgram, `closure_function`
the number of functions from the VM -- and the primitives' helpers (`jit_h_prim`,
`jit_h_primpush`) are given where their operands are in the code, which a
load may move. Where it became another, `jit_make` invalidates every
function that has code and makes the view again. `--jit-stress=N` invalidates the
callee's code at every Nth call into compiled code, so that
the oracle `jit` of `tests/runner/oracles.sml` holds every program to the interpreter's output
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
the oracle `jit` of `tests/runner/oracles.sml` in which every other function is compiled, so
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
  constant has it in a byte. Allocation failure stops emission and label
  patching; each successful reallocation immediately replaces its owned
  pointer, so cleanup is safe if the next allocation fails. The
  `x64-allocation-failures` check moves every reallocated buffer and fails
  each allocation in turn.
* **`masm.h`, `masm.c`**: the macro-assembler, and the conventions the
  code keeps. `r13` is the VM (`r12` would make every memory operand
  based on it a byte longer), `r14` the frame's registers (the stack plus
  8 times the base), `r15` the count of instructions; register k is the
  8 bytes at `[r14 + 8 k]`, and the frame's header the three words below
  (`[r14 - 8]` the return word, `[r14 - 16]` the closure, which `ENV`,
  `SELF` and a tail call read and write, `[r14 - 24]` the info word).
  `rbp` is the allocation pointer since native-frames.md's M8 (M4 freed
  it; performance M6 kept the frame's record in it).
  The stack itself has no register: what moves between frames reads it
  from the VM. The fields of the VM that the code names most are the
  VM's first 128 bytes (`vm.h`), where an offset is one byte of an
  instruction and not four. The
  machine stack holds only the call into C in progress, aligned by the
  enter stub; the code never pushes. `SYNC` writes the stack pointer (the
  frame's base plus its registers, plus what a primitive's arguments
  push), the pc after the instruction, the count and the frame's base
  and function to the VM before any call into C -- the code keeps the
  frame in `r14` alone, a call and a return touching no `VM.fp` (M6), so
  the base is made from it there (`ms_store_fp`: `r14` less the stack,
  over 8), as on the way into the interpreter and in the stubs;
  `RELOAD` takes the stack, the frame and its registers back
  after one, since a call may move the stack and a raise the frame. A
  call into C takes the System V or the Windows convention (`ms_call`;
  the VM is argument 0). The allocation fast path is `vm_alloc`'s in
  line (native-frames.md, M8): the allocation pointer, `alloc.from` plus
  `alloc.used`, is in `rbp` (`x21`), and an object is `mov rax, rbp; add
  rbp, size; cmp rbp, [vm.alloc_limit]; ja slow`, the count of objects
  and the header -- `VM.alloc_limit` the end of `alloc`'s room, which C
  makes again wherever it changes (`vm_alloc_limit`; `--gc-verify` checks
  it), and 0 under `--gc-stress`, so that every allocation goes to C, which
  stresses as the loop does. The bytes are counted from the pointer's
  progress: `SYNC` writes `alloc.used` back and adds what the pointer moved
  since to `bytes_allocated`, and `RELOAD` takes the pointer again, as do
  the stubs that leave for the interpreter and the enter stub; the slow
  path takes its bump back first. A store into an object that exists (`ref_set`,
  `array_update`, `SETENV`) is `ms_set_field`, or `ms_set_element` for an
  array's element, the store and the barrier in one operation, which sees
  the object, the field and the value as C's `gc_barrier` does (the array
  kept beside its element's address, since a barrier finds what it marks
  from the object), and emits the store, then the barrier: where the value
  stored is a pointer into alloc's room and the object is not in it, and
  there is a nursery, the card of the field in the object's chunk and the
  card's block are marked (R_S2, R_S3 and R_S6 clobbered); a fill of a
  fresh object is `ms_store_field` alone. A kind is tested by `kind_is`: the
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
  with the primitive for what an int does not hold and for a NaN. The
  primitives that are a function of the C library on reals and nothing
  else (`real_exp`, `real_ln`, `real_sin`, `real_cos`, `real_tan`,
  `real_atan`, `real_sinh`, `real_cosh`, `real_tanh`, `real_atan2`,
  `real_pow`: `jit_libm_of`) are that function called by the code
  itself, the double in `xmm0` (and `xmm1`) and back in `xmm0`, with no
  sync and no reload: the homes C would clobber that are live at the
  instruction's start or after it wait in the VM's cells as they are
  and are loaded again (`ms_call_pure`). Slow paths (a fatal
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
  added to the count where the run begins (docs/native.md, *Counting*) --
  a run ends where control goes elsewhere or comes from elsewhere, not
  where it may leave (a raise: M6 of docs/plans/performance.md, counting
  per extended block), so a sync in its middle gives the VM the count
  less the rest of the run (`Masm.ahead`), and a raise into a handler's
  code takes the count back from the VM --
  the slow paths, and the code copied into the region, which is one
  64 MB mapping, executable, made writable to add a function's code. At
  its start (`jit_region_init`) are the enter and leave stubs, the stub
  of fatal errors, the return trampoline, the stub of a call into the
  interpreter, the return barrier's stub (`ms_emit_barrier`: where the
  `RET` of the frame at the stack's watermark goes; native-frames.md,
  M5) and a trampoline for every call into C the code makes
  -- every primitive and every helper -- where a function anywhere in
  the region reaches them by a direct jump or call (`ms_call`,
  `ms_handback`; `placed` in the masm says the code knows where it will
  run). A code object's entry is
  written last. The helpers native code calls: `jit_h_prim` (the
  primitive from the registers, `fastprim.h`'s way, or pushed and
  called), `jit_h_alloc`, `jit_h_return` (a `RET` into a caller that is
  not compiled code, and the top level's, through the return trampoline
  `VM.ret_tramp`, answering what the driver is to do next),
  `jit_h_enter_interp` (a call into a function that has no code, through
  the stub the table of calls gives it), `jit_h_fatal_at` (the
  loop's message, from the stub), `jit_h_push_handler` (where the
  table of handlers is full), `jit_h_raise`, `jit_h_interrupt` (the
  user's interrupt raised from a poll), `jit_h_primpush`,
  `jit_h_barrier` (a return through the stack's return barrier, which
  lowers the watermark: native-frames.md, M5) and `jit_h_grow` (the
  stack's clean part claimed where a call finds no room).
* **`emit.c`**: the emitters, one per instruction, over the
  macro-assembler. `runeisa` writes `runtime/register/jit_emit.h`, their
  prototypes, so that an instruction without one does not build, and
  `runtime/register/jit_cases.h`, the walk that reads each instruction's operands as
  the loop reads them and calls its emitter; the flow, raises and handlers
  of each instruction are the tables of `regops.h`.

Calls, returns, handlers and `PRIMPUSH` in tier 1 (M5, made lean by M6
of docs/plans/performance.md and by native-frames.md's M4): a known call
(`CALLK`, `TAILCALLK`) is in line -- the room checked in the stack's
clean part (whose slow path claims more, and is the call's poll), the
callee's registers made above the frame and a header from the caller's
(the rest as the clean part has them), the header's return word written
-- the address of the call's *landing* in line after it, at an odd
address (a `nop` before it on x86-64; on aarch64, whose instructions are
words, the address and 1, `JIT_RET_BIAS`) -- and its closure `unit` where
the callee reads one, `r14` moved to the callee's registers, and its
code jumped to: a call to the function itself to its entry's label,
another's that has code by `jmp rel32` to its address, the code's
placement being known before it is emitted (a function whose code jumps
into another's goes with it when that one is invalidated: `jit_depend`,
the callers recorded at the jump, `jit_invalidate` walking them), and
another's by a `jmp rel32` to a slow path that jumps where the *table of
calls* says (`JitProgram.calls`, `VM.jit_calls`; `CallInfo`): per
function where a call goes in -- its code's entry, which compiling it
puts there, or the stub that hands the frame, its header and registers
made, to the interpreter (`ms_emit_call_interp`, `jit_h_enter_interp`,
the callee's function's word in `r11`) -- and the room its frame wants. That
jump is recorded with the callee (`CodeObject.pending`) and made a jump
into the callee's code when the callee is compiled (`patch_pending`,
unless the caller's code is gone or compiled again; the caller then
depends on the callee as above). A tail call writes the arguments
straight into the slots that are the callee's registers where no
argument is read from a slot an earlier one wrote, else above the frame
first and then down. **Arguments in registers** (native-frames.md, M6):
where the callee is this function or one compiled already at tier 2,
whose code takes its parameters at its *register entry* -- its first
instruction's label, past the entry's landing, which loads them from
their slots (`CodeObject.reg_entry`, `param_home`) -- a known call, and a
tail call that leaves no argument to a slot, puts each argument's word
straight into the callee's home for it, as a parallel move (`rax` breaks
a cycle), a parameter without a home into its slot and one the callee
never reads nowhere, and jumps there; the callee's slots of those
parameters are written when its homes are, at its first safepoint. A
parameter whose home is raw, a register read at the entry that no
argument gives, and tier 1 keep the slots; so do calls through a closure,
whose callee is not known. A call through a closure (`CALL`, `TAILCALL`) finds
both in that table by the word of the closure's function (`2f + 1`: the
entry at 8 times it less 8, the room at 8 times it; checked against the
number of functions where the section does not vouch for the closure),
the room claimed (a slow path claims and starts the instruction over),
the registers made, the header's closure and return word written and
the entry jumped to. `RET` takes the value's word into `rax` and jumps
where the frame's return word says, testing nothing: two instructions
-- to the landing of the caller's compiled call, which moves `r14` back
by the caller's registers and the header, loads the homes needed after
the call and stores the value into the register of the `RESULT` -- or,
for a caller that is not compiled code
and for the top level, to the return stub `VM.ret_tramp`, whose word
every frame the interpreter or the runtime pushes keeps (`VM.ret_word`;
the debugger's debug mode, invalidation and a new world give it to the
frames that need it, and frames there before the region was made get
it then), and which hands the return to the interpreter (`jit_h_return`,
which pops the frame as its info word says; the top level's has no
caller). The interpreter's `RET` into a frame whose return word is a
landing hands the VM to the driver, which enters the landing with the
value (`VM.ret_value`, which the enter stub loads into `rax`) and the
frame that returns still the VM's. **Under `--jit-returns=call`**
(native-frames.md, M7) a call is a `call` and a return `push [r14-8];
ret`, so that the processor predicts the return: the call's landing is
its return address, made odd by the length of the `lea` that moves `r14`
before it (a byte of SIB more or not), and the callee's *call entry*
stores it as the return word (`pop [r14-8]`; on aarch64 `bl`, the link
register and 1 stored, and `ldr`, `sub` and `ret` to return). A
function's code then begins with its call entry -- the parameters' homes
loaded, the return address stored, and on at the first instruction, where
a call with its arguments in registers enters past the loads -- and the
driver's entry, which has nothing to store, loads them after the code and
jumps there; the table of calls gives call entries, the stub of the
interpreter stores the address too, and a jump to such an entry (a tail
call through a closure, or through the table) pushes the return word
first. **The stack's watermark**, below
which a minor collection does not scan, is kept by a *return barrier*
(native-frames.md, M5; `isa_regs.c`): the frame at the watermark -- the
frame that ran when the last collection ended, or the lowest a return
or a raise has reached since -- has the barrier's stub for its return
word (`VM.barrier_stub`, at `VM.barrier_at`, its own word in
`VM.barrier_word`), so that its return, the only one that goes below the
watermark, goes through the stub, which lowers the watermark to the
caller, moves the barrier there and goes on where the frame's own word
says (`jit_h_barrier`, `reg_barrier_pass`; the loop's `RET` likewise).
No other return compares anything. Each return through the barrier since
the last collection moves it twice as many frames down as the one before
(to 1024), so that a deep recursion that unwinds passes it at every
2^k-th return, not at every one, and the next collection scans at most
twice the frames that ran. A collection moves the barrier to the
frame that runs (`vm_frames_mark_low`), a raise or the debugger's frame
dropped below it to the frame they leave running; the walk and every
reader of a return word see through it; `--gc-verify` checks that it is
at the watermark, and `--jit-stats` counts the returns through it.
So a `RESULT` after a `CALL` or `CALLK` is passed over by every engine
and counted by none (compile.c, a phantom), where a `RESULT` after a
`PRIMPUSH` runs and takes the value the primitive left above the
registers. `PUSHHANDLER` records, beside the pc, the address of the
handler's code (`Handler.native`, `runtime/vm.h`; NULL from the loop's and from
an image), so that a raise -- `RAISE` through `jit_h_raise`, a primitive's
through `jit_h_prim` -- lands in the handler's native code where it has
some, from the interpreter too (`RAISED` in the loop's words). Since
docs/plans/performance.md's M5 the handler is written in line where the
table has room, as `vm_push_handler` writes it, and a `RAISE` unwinds in
line where nothing else is to be done -- no debugger watching raises
(`Debugger.raise_mode`), a handler there that is not the REPL's
(`VM.raise_mark`, whose raise records the frames it leaves) and whose code
is compiled and whose frame is not below the stack's watermark (where
the barrier must move, which the helper does): the handler popped, its
frame the VM's, the exception at its stack pointer, and on into its code,
which loads its homes from the slots (written back first in a function
with handlers). `--trace`
runs the interpreter alone. The user's interrupt is polled where the loop
polls it (`POLL`): at a jump back, a compare of `VM.interrupt` and a
branch, before the instruction does anything, to a slow path that goes
back while the mask holds it and else raises it through
`jit_h_interrupt`, as `RAISE` raises; at a call, by its room check,
whose slow path claims and then looks at the flag the same way (the
stack's clean part above: the interrupt makes its end 0)
([docs/runtime.md](../../docs/runtime.md), *Interrupts*).

Made fast (M7): **the primitives of `fastprim.h` are in line**
(`prim_inline` in `emit.c`), each exactly what `prim_fast` gives and to
a slow path -- the helper, which does the primitive as the loop would
and may raise -- wherever `prim_fast` would answer 0 (a tag that is not
the one, an overflow, a divisor of 0 or -1, an index out of bounds);
`=`, `ptr_eq` and the order of strings are in line too (performance M5;
`fastprim.h` does the same in the loop): `poly_eq` on a pointer decides
in line what needs no walk (`ms_equal_heap`, `masm.c`) -- an immediate
against a pointer, a pointer against itself (but a real's box: a NaN),
objects of different kinds, refs and arrays by their address, boxes of
numbers by their bits, strings by their lengths and then a word at a time
(`ms_string_equal`) -- and `--jit-stats` counts its calls and those
walked in C; `string_eq`, the compiler's `=` of strings, is the same
compare of strings, in line whatever their length; `ptr_eq` is a compare of words, but for two boxes of one
number; `string_order` and `String.<`, `<=`, `>` and `>=` compare in line
where the shorter string is at most 8 bytes (a word of each, its bytes in
the other order, the rest shifted out: `ms_string_order_short`), else call
`jit_h_string_order`, which touches nothing of the VM and is called with
nothing synced or reloaded: the homes C clobbers wait in the VM's cells
around it (`ms_save_volatile`), and its arguments come from scratch
registers, never from homes, which the arguments' registers may be.
Else `poly_eq` on a pointer
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
puts the bool back into the flags. At tier 2, where the bool goes to
that branch alone -- dead after it either way, and the branch reached
from the comparison only -- and the section vouches for both words in
their homes, no bool is made at all: the words are compared where they
are and the branch reads the comparison's own condition (`cc_for`,
performance M6), as `int_add` and `int_sub` on two such words compute
where they are, `rax` the one scratch. **Unit goes only where it is
needed:** for a callee without an arity in the section, a call fills
its registers from the lowest one not provably written before the
first instruction at which a collection could see it or control could
arrive from elsewhere (`jit_fill_from`, from the generator's
`rop_dest`, the operand an instruction writes); every other frame is
made in the stack's clean part and needs none (M6). And
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
  or a `Word64.word`, and since M7 of docs/plans/performance.md a
  pointer, a constructor or anything at all, in one of six general registers (`rbx`, `r12`,
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
  (`emit.c`).
* **Pointers** (M7 of docs/plans/performance.md, D6 A). The collector's
  roots are the slots, as at tier 1: a home that holds a pointer is
  written back at every safepoint like any other, and since the
  collector moves what it points to, it is loaded again from its slot
  after every call into C that may collect, though C keeps its register
  (`may_move`, `masm.c`); a lean call collects nothing and leaves it be.
  Such a home -- a pointer's, a constructor's, or one of a register the
  section says nothing of, all tagged `T_PTR` (`is_any_word`) -- holds
  the word as the slot would, whatever it is: its tag, kind and length
  are tested as a slot's are where the section does not vouch for them
  (`ms_check_tag`, `ms_load_obj`, `ms_load_tag_of_con`). A real or a
  number of 64 bits moved into it from a raw home goes through its slot,
  boxed there where it has no immediate (`ms_move`, `ms_need_word`; a
  result of 64 bits into it, `ms_set_num64`). Under `--gc-verify` and
  `--gc-stress` the code checks after every call into C, where it synced
  first, its frame is the VM's still and no collection ran, that every
  home C kept and that is live at the instruction's entry -- but the one
  it defines -- agrees with its slot, a pointer's before it is loaded
  again: one that does not is a fatal error naming the register
  (`ms_reload`). And `--gc-verify` fills the nursery with garbage after
  a minor collection, so that a home not loaded again holds a pointer to
  no object at once (`runtime/gc/minor.c`). A string's comparison in C
  takes its arguments from scratch registers, never from homes, which
  the arguments' registers may be (E12's bug;
  `tests/lang/rt.gc_pointer-homes.sml`).
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
* **Constants known, and division by them** (functors-units M1). The
  emitter knows which registers hold a constant at the instruction it is
  emitting: those an `INT`, a `CONST` of a number (an immediate, or a
  box of 64 bits) or a `MOVE` of such a register set earlier in the run,
  and that nothing has written since (`Jit.known`, `known_after` in
  `compile.c`; at most eight, the oldest forgotten). It forgets them all
  where control arrives from elsewhere -- a target, which every landing
  is -- and after an instruction that does not go on to the next. A
  `PRIM` of `int_div`, `int_mod`, `int_quot`, `int_rem`, `word_div` or
  `word_mod`, or of `Int64.int`'s and `Word64.word`'s, whose divisor is
  such a constant other than 0 (and -1, signed) is then a plan worked
  out when the code is made (`divplan.h`) and its steps on the
  dividend's payload or 64 bits (`ms_div_const`): a power of two by
  shifts and masks; a signed `div` or `mod` by a positive divisor as
  `s ^ floor((n ^ s) / c)`, `s` the sign's mask, by Granlund and
  Montgomery's unsigned magic number; `quot`, `rem` and a negative
  divisor by *Hacker's Delight*'s signed one and the floor's fix-up; a
  word by the unsigned one, of 65 bits where its dividend has 64. No
  test of the divisor and no branch: `Pickle.hash`'s `x mod 16777213` is
  17 instructions from the dividend's home to the result's, one `mul`
  among them, where `cqo; idiv` was behind three tests and before a
  fix-up with branches. The divisor 0 and -1 keep the general
  path, which raises `Div` and `Overflow`; so does a divisor read when
  the code runs, and every division at tier 1. `--jit-stats` counts the
  divisions of code by a constant and the rest
  (`tests/lang/rt.div_constant.sml`, `tests/register/divconst_test.c`).
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
* **Calls.** A `CALL` or `CALLK` writes back first the homes the frame
  needs after it -- live where it returns, but for the register it
  returns into -- since the callee has the machine registers; they are
  loaded again at the call's *landing*. An argument that dies at the
  call goes from its home into the callee's register and is not written
  back (where its home is raw, its slot is given its word first,
  `ms_need_word`). In a function with a handler every home live at the
  call is written back, what a handler needs being live at every call
  in its scope, and so at a call through a closure under
  `--jit-profile`, whose helper loads them again (`ms_writeback_call`,
  `masm.c`). A `TAILCALL` replaces the
  frame: only its argument wants a word.
* **Landings.** Wherever code is entered from outside -- the entry,
  the instruction after a call, a handler, the loop heads and run starts
  the interpreter enters mid-way (`jit_osr`) -- a landing loads the homes
  live there and goes on to the instruction's label (`jit_landing`);
  the entry's landing loads the parameters' homes, and a call to the
  function itself jumps to it. Jumps within the function go to the
  labels, since the homes are the function's throughout. The OSR table
  and a handler's `native` hold landings; a frame's return word holds
  the call's own, which loads the homes needed after the call in line.
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
(`ms_immediate`). A constructor's tag is tested by what the section
says of its register (native-frames.md, M2; `ms_jump_unless_tag`, and
`ms_load_tag_of_con` for `SWITCH`): a datatype of nullary constructors
alone is its immediate, so `JUMPIFNOTTAG` compares the word with the
tag's; one whose constructors all carry a value is a pointer, whose tag
is loaded with no test of the word; a mixed one is tested for its low
bit and then compared as the immediate it is or by its object's tag,
with no kind tested. At either tier, the test of a constructor's tag
under `--checked` (`FIELD`, `DECON`) is compiled in only when the VM runs
under it, which the command line says before any code is made; and
`int_mod` by a positive power of two -- the size of a hash table -- is an
`and` with one less than it, which is the floor's remainder of a
negative dividend too, where an `idiv` takes tens of cycles; no negative
divisor passes the test, a payload being 63 bits (`Int64.int`'s keeps
the division). The loader's lint holds a program to its section; a
program that lies to it runs wrongly at tier 2 where the interpreter
and tier 1 would have stopped it. **A function's code fills none of its
registers with unit** (M6 of docs/plans/performance.md; M10 to M5 of
it, the code filled from its arity up): its caller made its frame in the
stack's clean part, whose slots are unit or values written since the
last collection, roots as they are; a caller fills for a callee without
an arity in the section (`fill_unit`, `fill_unit_dynamic`;
`jit->all_meta` says every function has an arity). `Math.sqrt` is in
line (`sqrtsd`).

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
without code, a return into a frame that returns to the interpreter and a raise
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
`llvm-mc` gives, `tests/register/x64_test.c` and `a64_test.c`). Both encoders
stop emitting, recording references and patching labels after allocation failure,
and check patch offsets against the emitted buffer. `x64_fail_test.c` and
`a64_fail_test.c` fail every allocation in a workload with a moving
allocator, then finish and destroy it; they also fail a table word at the
buffer's end with forward and already bound labels. The AArch64 encoder
uses a single array of references, so it has no paired-reallocation
ownership to keep, but its table patches need the same failure guards.
Trampoline padding also stops on failure; otherwise its alignment loop,
or the Windows x86-64 trailing padding loop, can wait forever for a failed
buffer to grow. Both allocation fixtures cover these paths too.
What the implementation gives:

* **The registers**, under the portable names: the three the code keeps
  (`R_VM`, `R_BASER`, `R_COUNT`; and `R_BASEI`, the allocation pointer
  since native-frames.md's M8), seven scratch registers
  (`R_S0`, the return value of a call into C, to `R_S6`) and two
  floating (`F_S0`, `F_S1`); and tier 2's homes, which have no names
  but a table by the convention of the calls into C: `as_home_g` and
  `as_home_f` give the kth, `as_keeps_g` and `as_keeps_f` say what a
  call into C keeps. x86-64 keeps `r13`, `r14`, `r15` and `rbp`; its
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
  of an `xor` tests it); the bytes of a register in the other order are
  `as_bswap` (`bswap`, `rev`: M5's order of strings); a multiply that may overflow is one operation
  with its jump (`as_mul_jo`: `imul` and `jo`, or `mul`, `smulh` and a
  compare); a divide gives the quotient in `R_S0` and the remainder in
  `R_S2` (`cqo` and `idiv`, or `sdiv` and `msub`), and the high half
  of a product `R_S2` too (`as_smulhi` and `as_umulhi`: the one-operand
  `imul` and `mul`, which take `rax` and leave the low half there, or
  `smulh` and `umulh`); a shift by a
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
first, and the steps of a division by a constant against C's division
(`tests/register/divconst_test.c`, built for aarch64).

## Calls into C: the transition, and the FFI's

Native code calls into C in one way, wherever it does (`masm.c`, `ms_sync`,
`ms_call`, `ms_reload`), and this is the sequence a foreign function
call will take too (docs/plans/jit.md, *Prerequisites and flags*, the
FFI):

1. **`SYNC`:** the VM is made exact where C can look -- `vm->pc` the pc
   after the instruction (what a trace, an error and an image would
   name), `vm->sp` the frame's base plus its registers plus what the
   instruction has pushed, `vm->instructions` the count, `vm->fp` and
   `vm->func` the frame's base, from `r14`, and its function (since
   performance M6 the code keeps its frame in a register alone). The
   frames below are exact in the stack, each header written by its
   caller (native-frames.md, M4).
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
   nothing synced or reloaded (M7), and says so where it is declared; a
   function of the C library on reals (`sin` and the like) is called
   so too, the VM not its argument (`ms_call_pure`). What it may not do is run
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
allocated, and `make perf-check` holds them to `tests/perf/*.budget`.
Cycles are `bin/rune-measure perf-cycles`, whose configuration `rune` is this VM
as shipped (docs/plans/jit.md, *Measuring*; docs/performance.md).
`--jit-dump=DIR` (docs/plans/performance.md, M1; `jit/dump.c`) writes the
code of every function compiled, as placed, and what each part of it is
for: the bytecode instruction it does and its *role* -- the instruction's
own work, or what the protocol around it costs: the count of a run, the
poll, a call's write-back of the homes, its arguments, its room checks,
its frame's header and its jump, the fill with unit, a landing, a return, a
slow path, the VM made exact for C, a closure's lookup, a pointer loaded
from its slot, a tag test, an allocation (`MsRole`, `masm.h`). The
macro-assembler keeps the marks where the role changes (`ms_role`,
`ms_mark_pc`) when the dump asks for them, and nothing else; an emitter
that adds a part of the protocol says its role, so that the dump keeps
telling what a call, a return or a primitive costs. `bin/rune-measure jit-dump`
disassembles the code with each machine instruction's role, and counts
the instructions callgrind saw by role (the cost of a call is the
difference of two runs, per call); the same directory holds perf's
jitdump of the code, so that `perf record -k mono`, `perf inject --jit`
and `perf annotate` read it. `make test-register-jit` holds the dump to
its format (`tests/register/jit-dump.py`).
`make test-register-jit` (part of `make check`) runs `tests/lang` and the Basis
Library suite with every function given to the JIT (`--jit=all`), holds
every program of `tests/lang` and `tests/perf` and the primitives' edge
cases to the same output and `--count` in both modes and every
instruction to occurring in them (the oracle `jit` of `tests/runner/oracles.sml`), runs
`--jit-check`, and a recursion 200,000 deep under a machine stack of 1
MB; `make test-stress`, `make test-register-asan` and `make test-windows` run
the suites under the JIT as well.
`make test-register` (part of `make check`) runs `tests/lang` on it, holds every
program's allocation and the compiler's own output to `runevm-stack`'s and the
primitives of `fastprim.h` to their edge cases (the oracle `register` of `tests/runner/oracles.sml`),
and runs the Basis Library suite; `make test-register-asan` and `make
test-stress` run `tests/lang` with the sanitisers and with a collection
every 101st allocation; `make test-windows` and `make test-portability`
run the suites on the other machines' builds.

## Optional IntInf arithmetic

The register VM can link `runtime/intinf.c` with GMP ahead of the shared
GMP-free archive. SML dispatch reads the current VM's capability on each
large operation; every tier calls the same generated primitives. Values and
images contain canonical small integers or immutable magnitude bytes, with
no GMP pointers. GMP objects are scoped to a primitive call and its allocator
is separately budgeted. See `docs/runtime.md` and `docs/plans/gmp.md`. Count
comparisons across stack, native and register engines force SML; comparisons
across register tiers also run separately with GMP.


Cross builds select a separately checked GMP prefix for each ABI. Build
availability changes no primitive identity or bytecode fingerprint. Image
format 14 keeps only canonical Rune values, finite arithmetic limits, and
fork policy; a saved world's backend is selected by the restoring VM.
The cross-platform arithmetic suite compares counts within each backend,
with distinct records for GMP's native allocations and conversion costs.

## Foreign callback delimiters

A synchronous callback enters `vm_callback_loop`, the plain interpreter with
no `JitProgram`. Its root frame's RET returns to an explicit delimiter before
reading its parked caller's return word. No callback compiles, tiers up,
invalidates code, changes executable pages, enters native code, or calls the
ordinary `vm_loop` driver. Nested foreign calls may open another bounded
callback scope. Suspended native frames retain exact GC live masks by frame
identity; stack and frame relocation restore native safepoint addresses by
index. See [the callback contract](../../docs/ffi/callbacks.md).
