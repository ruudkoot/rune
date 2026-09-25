# vm/new as built

The virtual machine for the register bytecode, as it is: enough, with the
sources it names, to build it again. Every change to `vm/new` keeps this
current (`AGENTS.md`). What is planned for it is
[docs/plans/jit.md](../../docs/plans/jit.md); what a program can count on is
[docs/runtime.md](../../docs/runtime.md); the instruction set is described
in [docs/bytecode.md](../../docs/bytecode.md) and `src/isa/regs.sml`.

## What it is made of

`bin/runevm-new` is `vm/main.c`, `vm/new/interp.c`, `vm/new/isa_regs.c` and
`vm/new/jit.c` linked against `build/librune.a`, the runtime `runevm` is built from
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
`reg_labels.h` and `src/backend/regcodes.sml` -- are written by `runeisa`
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

A frame is `{func, ret_pc, base, closure, native_ret}` in the array
`vm->frames`; the handlers `{pc, sp, fp}` are a second array; the value
stack a third. All three grow by doubling (`realloc`), which moves the
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
it is interpreted; its tier; the counters tier 0 will keep for the
tiering policy; and, from M4, its code's table of pc to address. An entry
is published last, with one store. `--jit=off` runs the interpreter alone,
`--jit=all` gives every function an entry at load, `baseline` and `opt`
are the tiers of M6 and M9; `--jit-stats` prints at exit what the JIT did.
`--jit-check` allocates executable memory through the system layer
(`sys_code_alloc`, `sys_code_protect`, `sys_code_flush`,
`sys_code_free`; `vm/sys.h`), writes a few bytes of this machine's code
into it and runs them. A VM built with `RUNE_JIT=0` has the interpreter
alone and refuses `--jit`.

Until M4 the only entry is a stub: `jit_run` answers `RUN_INTERP` for it,
and the interpreter runs the frame. Under `--jit=all` every call thus
crosses the driver twice, which is the cost of the protocol itself,
measured in M3.

## Images

An image (`vm/image.c`) is in bytecode terms and shared with `runevm`, with
the register instruction set's fingerprint in its magic. The places a
program resumes at are the `RESULT` after a `PRIMPUSH` (`rt_save`,
`rt_restore`, `posix_fork`, which leave their result on the stack) and,
for each frame, the `RESULT` after its call. A resumed VM enters
`vm_loop`, which makes room for its frames first.

## What is measured, and how

`runevm-new --count` counts instructions executed and bytes and objects
allocated, and `make perf-check` holds them to `tests/perf/new/*.budget`.
Cycles are `scripts/perf-cycles.sh` (docs/plans/jit.md, *Measuring*).
`make test-new-jit` (part of `make check`) runs `tests/lang` with every
function given to the JIT (`--jit=all`), `--jit-check`, and a recursion
200,000 deep under a machine stack of 1 MB.
`make test-new` (part of `make check`) runs `tests/lang` on it, holds every
program's allocation and the compiler's own output to `runevm`'s and the
primitives of `fastprim.h` to their edge cases (`scripts/check-new.sh`),
and runs the Basis Library suite; `make test-new-asan` and `make
test-stress` run `tests/lang` with the sanitisers and with a collection
every 101st allocation; `make test-windows` and `make test-portability`
run the suites on the other machines' builds.
