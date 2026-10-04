# The runtime

`runevm` is the program a compiled Rune program runs on: it loads a `.rbc`
file, checks it, and interprets it (`runtime/`, about 9,500 lines of C). This
page is about what a running program can count on -- how a value is laid out,
when the collector moves it, how much memory and how many objects a program
may have, what makes a run reproducible, and where the platform shows
through.

Two neighbouring pages: [bytecode.md](bytecode.md) is the file format, the
instruction set, the primitives and the command line;
[architecture.md](architecture.md) is which file of `runtime/` does what.
[building.md](building.md) covers building the VM, including for Windows.

## Values and objects

A `Value` is one 64-bit word, on every machine. Its low bit says what it
is: set, the word is an *immediate*; clear, it is a pointer to an object in
the heap. That is so whatever the machine's pointer width, which is why
`Int`, `Word`, `Real` and the positions of files are the same on a 32-bit
VM as on a 64-bit one.

These are immediates, and cost nothing to make:

* `unit`, an `int`, a `word`, a `char` and a constructor with no argument
  (`nil`, `true`, `NONE`, and every other nullary one, which is its tag as
  a number): the number *n* as the word 2*n* + 1. That leaves 63 bits, which
  is the width of `int` and `word` ([Numbers](#numbers)).
* a `real` whose exponent is in the middle half of a double's, a number
  from 2^-511 up to 2^513: its bits with 2^61 added, rotated left by two,
  which sets the low bit for exactly those.

Which of them an immediate is, the word does not say and the program's
types do: an `int` and a `char` of the same number are the same word.

What does not fit a word is a *box*, an object of 16 bytes that holds 8
raw bytes: a real outside that range -- zero, the subnormals, the
infinities and NaN among them -- and an `Int64.int` or a `Word64.word`
that needs its 64th bit. The VM keeps one box each of `+0.0`, `-0.0`, the
two infinities and the quiet NaN from its start, so the ones a program
meets everywhere are never allocated.

Everything else is an object in the heap: an 8-byte header -- kind, a
constructor tag and a length -- and a payload of 8-byte fields, or of
bytes rounded up to a multiple of 8, at least 8. The kind is the low four
bits of the header's first byte; the other four are the collector's and
are zero under today's (*The garbage collector*). The smallest object is
therefore 16 bytes, and a tuple of *n* fields is 8 + 8*n* bytes. The kinds
are a tuple (also a record and a vector), a constructor with an argument,
a closure, a string, a `ref`, an array, an exception, an exception
constructor, the two boxes, and two arrays whose elements are not values:
an array of bytes (`Word8Array`, `CharArray`: a byte an element, where an
array of values takes eight) and an array of reals (`RealArray`,
`RealVector`: the doubles themselves, read and written without the word a
real has elsewhere). Both are laid out as C has them, and the collector
copies them without looking inside.

A constructor whose argument is a tuple is one object of the tuple's
fields, its tag in the header (`CONN`; `src/backend/rep.sml`); one of any
other argument is an object of one field around it, 16 bytes. So a list
cell, `::` of head and tail, is one object of 24 bytes. `runevm --stats`
and `--count` report what a program really allocates; `--count` leaves
the boxes out, so that its bytes and objects are the program's own and
the same on every engine, and `--stats` gives them a line of their own.

Two switches of the build, for measurements and not for use
([plans/heap-layout.md](plans/heap-layout.md), D2 and D3): `-DRUNE_INT64`
makes a VM whose `int` and `word` keep 64 bits, with a box past 63, for
bytecode compiled with `rune --int-bits=64`; `-DRUNE_REAL_BOXED` one that
boxes every real.

An exception constructor is an object, and its identity is its address: that
is what makes two exceptions declared by the same code in two calls different
values, and it survives a collection and a `fork` (below).

## The heap

Everything a program allocates is in one heap: tuples, constructors,
closures, strings, refs, arrays, exceptions, and the boxes of the numbers
that have no immediate (*Values and objects*). Allocation is a bump of a
pointer in the current semispace, in the VM's C and in line in compiled
code; nothing is ever freed one object at a time. The value stack, the
frames, the handlers and the program's code are not in the heap.

* The first semispace is 4 MiB, and `runevm --heap-size N` sets it (at least
  4096 bytes).
* After a collection the heap grows -- doubling -- until the live data is at
  most half of it and the request fits. `runevm --heap-fill P` makes that
  *P* percent instead (1 to 100): a quarter makes about half the collections
  for twice the memory. A heap that would have to double past
  what a `size_t` can hold ends the run with `runevm: out of memory`.
* It never shrinks, and it grows by doubling alone, so the memory a run
  takes moves in steps: the compiler compiling itself keeps 42 MB at most
  and runs in semispaces of 134 MB.
* From the first collection on there are two semispaces while the heap
  stays the size it is; a collection that grows it frees them and makes one
  of the new size, and the next collection the other. So the process holds
  up to twice the semispace `--stats` prints, beside its stack and its
  code.
* `runevm --heap-limit N` caps a semispace (at least 4096 bytes; no cap by
  default). At the cap the heap may be fuller than `--heap-fill` asks; what
  is live and one more allocation not fitting ends the run with `runevm:
  heap limit exceeded`, a trace and status 2.

## The garbage collector

The collector is a Cheney two-space copier, one for every engine. When a
request does not fit, the live data is copied into the other semispace,
which is kept for the next collection while the heap stays the same size.
What it is and is not:

* **Precise.** Every slot of the stack and every field of an object is a
  word whose low bit tells an immediate from a pointer, so nothing is ever
  taken for a pointer that is not one, and nothing is scanned
  conservatively.
* **Stop-the-world, in one piece.** The program does not run during a
  collection. There are no generations, no increments and no second thread:
  every collection copies everything that is live, the data that has been
  live since the program started and a large array as much as a cell made a
  moment ago. Its cost is in proportion to what is live and to nothing
  else -- garbage is not visited -- at about 1.3 ns a byte copied on the
  machine of [performance.md](performance.md): the compiler compiling
  itself allocates 887 MB, makes 10 collections, and they copy 306 MB in
  0.4 s.
* **Moving.** A collection moves every object. Nothing of that is visible
  to an SML program: equality on `ref` and `array` is the identity the
  collector maintains, not the address of the moment.
* **Only at an allocation.** A collection happens when an allocation does
  not fit, when the program asks (`Runtime.collect ()`), and before every
  *N*th allocation under `--gc-stress N`. There are no timers and no polls:
  code that does not allocate is never interrupted. The same program on the
  same input with the same options collects at the same allocations in
  every run (*The same run twice*).
* **No barrier.** A store into a `ref` or an array is the store and nothing
  else.
* **No finalisers, no weak references, no pinning.** An object cannot ask to
  be told when it dies or to stay where it is; a file is closed by the
  program or when the process ends, not by the collector.

### The roots

The roots are the value stack, the globals, the constants of the program,
the closure of each frame, the built-in exception constructors and the
VM's boxes of zero, the infinities and NaN (`runtime/heap.c` lists them
once, for the collector and for an image whose heap moved). From those the
whole live graph is copied, so anything unreachable disappears without
being visited.

On the register VM, at every tier, the stack is a root by what is live
where that is known. A register of a frame that waits for a call is a root
only if the frame needs it when the call returns; a dead one that holds a
pointer is not copied and is made unit. So a list whose last use is before
a call does not survive the collections the callee makes, however long the
callee runs. The liveness is the one the JIT keeps its registers by
(`runtime/register/live.c`), worked out from a function's code the first
time a collection finds a frame of it waiting; nothing is added to the
bytecode, to an image, or to the code that runs.

### What is kept that the program no longer needs

Where the collector does not know what is live it keeps what is there,
which is always safe and sometimes more than a reader of the source
expects:

* **The frame that runs keeps every register.** What the function on top
  is doing when a collection comes is not known to the collector, so a
  value it has let go of is kept until its register is written again, or
  until the function calls another and waits. `Runtime.collect ()` is a
  primitive, done in the frame of the function that calls it: it does not
  drop what that function still has in a dead register (the one explained
  check of the Basis suite on the register VM,
  `Runtime.collect/drops-what-is-unreachable`).
* **Registers past a function's 64th are roots.** The liveness follows 64
  registers a function. Two of the compiler's 2,263 functions have more;
  the top level of a program is one function and usually does (the
  compiler's has 1,081), so a temporary of the top level may be kept until
  the program ends.
* **What any handler of a function needs is kept at every call of the
  function,** in the handler's range or not, since a callee may raise into
  a handler.
* **A global is a root for the whole run.** What is bound at the top level
  and used by a function is a global, whether or not anything will use it
  again.
* **The stack bytecode and native programs keep every slot.** On
  `runevm-stack` and in a program `runeopt` made every slot of the stack
  is a root. A slot there is reused by the next value of any kind, which
  drops some of what is dead by accident and none by design.
* **A value in an object is live while the object is.** A closure keeps
  what it captured and a record its fields, used again or not.

None of these changes what a program computes or what `--count` reports;
they change how much a collection copies, how large the heap grows, and
what `Runtime.stats` says is live.

### Watching it

* `runevm --stats` prints, at exit, the number of collections, the bytes
  allocated, the size of a semispace, the bytes in use (live data and the
  garbage since the last collection), the bytes every collection copied in
  all, the most a collection kept, the collector's processor time in
  microseconds and the longest single collection, which is the longest the
  program stood still; and the boxes the program made, which `--count`
  leaves out.
* `Runtime.stats ()` gives the collections, the bytes in use (boxes left
  out) and the size of a semispace to the program. The bytes in use are an
  upper bound of what is live, and right after `Runtime.collect ()` they
  are what the collector kept, with the list above.
* The processor time of the collector is measured around every collection and
  is what `Timer.checkGCTime` reports, so a program can tell its own time
  from the collector's.
* `runevm --gc-stress N` collects before every *N*th allocation. With `N = 1`
  every allocation moves everything, which is how `make test-stress` finds a
  primitive that keeps a heap pointer in a C variable across an allocation,
  and a register the liveness wrongly takes for dead.
* An image (`Runtime.save`) carries the heap as it lies, the garbage since
  the last collection with it; a `Runtime.collect ()` before it leaves that
  out.

Since a collection moves everything, C code inside the VM reads its arguments
from the value stack rather than holding them in variables; the pattern is in
[architecture.md](architecture.md).

### What is in place for a collector to come

The copier needs none of these; they are there, and tested, so that a
generational collector is a change to the collector and not to everything
that touches the heap ([plans/collector.md](plans/collector.md) is its
brief).

* **Four bits of the header are the collector's:** two for an age or a
  colour, one for "in the remembered set", one for "not to be moved"
  (`runtime/value.h`). They are zero in every object: no collector sets
  one, and none is planned to before the next collector's roadmap decides
  whether its bits go there or in a table beside the heap. So a kind is
  read as the whole byte, in C and in compiled code, which costs nothing.
  `bin/runevm-gcbits` is a VM whose collector sets the bits on every
  object it copies and whose readers take the kind's four bits alone, and
  `make test-heap` runs the language's tests on it: what a collector that
  uses them would turn on. An image does not hold them.
* **A store into an object that exists goes through one operation,**
  `obj_set_field` in C and `ms_barrier` after the store in compiled code,
  whose barrier is empty. The stores are `:=`, `Array.update` and their
  like, and the closing of a recursive closure (`SETENV`). `bin/runevm-cards`
  is a VM whose barrier marks a card, to measure a barrier before there is
  a collector that reads one: on a loop of `:=` it runs 4.7% more
  instructions, on the compiler compiling itself 0.3%.
* **Young and old are told apart by address** (`heap_is_young`): the test
  a nursery will make of its own range. Today every object is young.
* **An object can become an indirection in place** (`obj_become_ind`), its
  first field the value, and the collector follows that field alone: a
  lazy language's update of a suspension. No program of SML does it.
* **The collector's state is the VM's** (`GcState`), and where the next
  object goes is the allocating thread's (`AllocState`): no variable of
  the collector is the process's, so two VMs of a process collect each by
  itself, and a thread's own allocation buffer is one struct to change.

### What C can hold

Nothing stays where it is under the copier, so C keeps no pointer into the
heap across anything that may allocate. What it has instead
(`runtime/vm.h`; a foreign-function interface is not built, and these are
what it will stand on):

* **A handle** (`vm_handle_new`, `vm_handle_get`, `vm_handle_free`): a
  number for a value, in a table that is a root. The value is found again
  through it after a collection moved the object. An image has no handles.
* **A copy that stays** (`vm_pin`, `vm_unpin`): the bytes of an array of
  bytes or of reals copied out for C to keep a pointer to while the program
  runs on, and copied back into the object, wherever it is by then. There
  is no pinning in place: that needs a space that does not move.
* **The arrays C can read as they are:** an array of bytes and an array of
  reals have C's layout behind the header, so a primitive passes a pointer
  to their first element for the length of a call that does not allocate.

## Stacks, calls and exceptions

The value stack, the frames and the handlers are three arrays that start at
1024 values, 256 frames and 64 handlers and double when they are full, so
recursion is bounded by memory rather than by the C stack: the interpreter
loop does not call itself. A call that cannot grow them ends the run with
`runevm: out of memory (stack)`.

Tail calls do not grow the frame stack, so a tail-recursive loop runs in
constant space -- except in the body of a `handle`, where the handler has to
stay ([language.md](language.md), `rt.tailcall`).

A `raise` unwinds to the innermost handler, which is an entry recording the
code position, the stack height and the frame. With no handler left, the VM
prints `runevm: uncaught exception Name payload` on standard error, flushes,
and exits with status 1.

The exit statuses of the VM itself:

| Status | When |
|---|---|
| 0 | the program ran to its end, or called `OS.Process.exit 0` |
| 1 | an uncaught exception |
| 2 | a bad command line, a `.rbc` the loader refuses, or a fatal error of the VM |
| the program's own | `OS.Process.exit n` and `Posix.Process.exit n` |

`OS.Process.exit` flushes the streams and runs what `OS.Process.atExit`
registered; `Posix.Process.exit` ends the process at once and flushes
nothing, as POSIX's `_exit` does. A fatal error of the VM -- a stack
underflow, a bad opcode, an argument of the wrong kind -- prints
`runevm: fatal error at pc N in FUNC: ...` and exits with 2, where FUNC is
what the source called the function, qualified by the structures it is in.
It means the bytecode or the VM is wrong, never the program's input.

## Numbers

`Int` and `Word` are 63 bits on every VM, whatever the pointer width -- a
word of the VM less the bit that tells a number from a pointer -- and `Int`
arithmetic raises `Overflow` where `Word` wraps. `Int64` (which is also
`FixedInt`) and `Word64` (which is also `LargeWord`) are 64 bits on every
VM: a number of theirs is an immediate where it fits 63 bits and a box
where it does not, and tier 2 of the JIT keeps the 64 bits in a register.
`Real` is an IEEE double.

`IEEEReal.setRoundingMode` sets the hardware's rounding mode, and a child
made by `fork` inherits it, emulated `fork` included. Reading a numeral
rounds in that mode on every C library, because the VM does that rounding
itself: not every `strtod` obeys the mode.

Where a result may differ between two VMs of the same program, it is the
last bit of a transcendental function or of a conversion, and only on the
32-bit Windows VM:

* it is built with `-msse2 -mfpmath=sse`, so the arithmetic is SSE2 as on
  x86-64, but a `double` still comes back from a function in an x87 register,
  which can turn a signalling NaN into a quiet one;
* the 32-bit maths library is not the 64-bit one, and the two can differ in
  the last bit of `ln`, `exp` and their like.

The Basis Library suite records such a difference as a `WIDTH` line of
`tests/basis/deviations.txt` with its reason, rather than chasing it.

## What a program may have

| Limit | Value | Where |
|---|---|---|
| A string | 1,073,741,823 bytes | `String.maxSize`; longer raises `Size` |
| An array or a vector | 100,000,000 elements | `Array.maxLen`, `Vector.maxLen` |
| A file position | 64 bits | on every platform, including 32-bit Windows |
| Live data, 64-bit VM | the machine's memory | the heap holds both semispaces at once |
| Live data, 32-bit VM | about 512 MiB | `bin/runevm32.exe` is linked large-address-aware, which gives it 4 GiB of address space; without that it would be about half (an estimate: no test comes near) |

The ceiling of a 32-bit VM is lower than its address space because the
heap holds both semispaces at the same time. Running
out is a clean `runevm: out of memory`, not a hang.

## The same run twice

`runevm --count` prints, at exit, the instructions executed and the bytes and
objects allocated. Those numbers depend on the program and its input alone:
not on the machine, the pointer width, the heap size or the collector's
schedule. They are therefore performance budgets (`make perf-check`), and
they are how the Windows runner checks that a value and an object have the
same layout on all three VMs -- the counts of `bin/runevm`, `runevm.exe` and
`runevm32.exe` must agree to the byte.

What is *not* reproducible: the addresses of objects, the number of
collections (it follows the heap size), and anything the system answers --
the clock, the environment, the file system.

## The system layer

Everything the VM needs from the operating system is behind `runtime/sys/sys.h`: time,
files, directories, descriptors, processes, sockets and the `Posix`
structure. `runtime/sys/sys_posix.c` implements it for POSIX systems, `runtime/sys/sys_win.c`
for Windows ([building.md](building.md)), and `runtime/sys/sys_none.c` fails every
call with `ENOSYS`, which keeps the rest of the VM ISO C with no platform
code in it (`make SYS=none`).

A call the platform cannot make answers `ENOSYS`, which the library turns
into `OS.SysErr`. Which those are is listed per platform in
[basis-compat.md](basis-compat.md) and, for Windows, in the `WINDOWS` lines
of `tests/basis/deviations.txt`.

`fork` is the one place where a platform lacks something the library cannot
do without. Windows has none, so `Posix.Process.fork` starts a second VM and
hands it this one's whole state -- the heap, the stacks, the program, the
open files, sockets and directory streams -- and the child carries on from
the `fork` as a copied process would (`runtime/image.c`). `runevm --emulate-fork`
takes that path on a POSIX system too, which is how `make check` tests it.

The same image is what `Runtime.save` writes to a file and
`runevm --restore` carries on, in another process and on another machine:
nothing in the format is of a particular width or byte order, and a pointer
into the heap is written as its distance from the start of it, so an image
written by `bin/runevm` is restored by `bin/runevm32.exe`. What the system
layer holds is handed to a fork's child and cannot go into a file, so a
restored world has no sockets, directory streams or pipes; the files the
program opened are opened again by name, where they were left.

## Asking from inside

Most of this page is visible to a program through `Runtime`, which is Rune's
own and not in the specification: `Runtime.stats` gives the counters of *The
same run twice* and of *The garbage collector*, `Runtime.profile` the difference of two of
them across a call, `Runtime.collect` a collection on demand, `Runtime.trace`
the frames of *Stacks, calls and exceptions* as data, `Runtime.save` the image
this page describes under *The system layer*, and `Runtime.same` the identity
the collector maintains. The page of the signature is
[generated/basis/sig/RUNTIME.md](generated/basis/sig/RUNTIME.md), and
[../examples/runtime](../examples/runtime) has a program for each part of it.

## Loading a program

`runevm` treats a `.rbc` file as untrusted input: every offset, length and
index is checked before anything runs, and a file that does not pass is
refused with a message and status 2; `tests/runtime`, part of `make test`, is a
suite of crafted files and command lines that must all be refused so. A file
of another bytecode version is refused as well. There is no dynamic loading
afterwards: a program is one file, the basis library included.

The whole command line -- `--disasm`, `--trace`, `--stats`, `--count`,
`--gc-stress`, `--checked`, `--heap-size`, `--heap-fill`, `--emulate-fork`,
`--restore`, `--version` -- is described in [bytecode.md](bytecode.md).

## A native program

`runeopt` ([native.md](native.md)) translates a `.rbc` into a
program for Linux on x86-64 that runs on the same runtime, linked into it:
the heap, the collector, the primitives and the system layer of this page are
the ones `runevm` has, and so are the value stack, the frames and the
handlers, which the translated code keeps where the interpreter keeps them.
So everything above holds for it: the layout of a value, when the collector
moves it, the limits, the counters of *The same run twice* -- the same numbers
for the same run, which `make test-native` checks for every program of the
suite -- the trace of a failure, the messages, which still begin `runevm:`,
and the images, which name the places of the code by their bytecode, so
that the one writes what the other reads.

What differs:

* The options of `runevm` (`--count`, `--stats`, `--heap-size`,
  `--heap-fill`, `--gc-stress`, `--checked`) come from the environment
  variable `RUNEVM_OPTIONS`, after
  those the program was made with (`runeopt --options`), and the program takes
  the variable out of its environment.
* `CommandLine.name ()` is the name the program was started by.
* A native program carries on an image of its own program, whoever wrote it:
  `RUNEVM_OPTIONS="--restore FILE"`, `Runtime.restore`, and the child of a
  fork emulated by `--emulate-fork`. `runeopt --from-image FILE` makes the
  program of an image, and images cross between native programs and every
  VM, of every width and byte order. An image of another program is refused:
  `Runtime.restore` raises `OS.SysErr` with `ENOEXEC`, where `runevm` would
  become the other world, since the native code is the translation of its
  own program alone.
* The program carries its line table as DWARF: a debugger stops at a line of
  an SML source, and names a function by its name and its number.
