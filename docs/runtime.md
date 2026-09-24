# The runtime

`runevm` is the program a compiled Rune program runs on: it loads a `.rbc`
file, checks it, and interprets it (`vm/`, about 9,500 lines of C99). This
page is about what a running program can count on -- how a value is laid out,
when the collector moves it, how much memory and how many objects a program
may have, what makes a run reproducible, and where the platform shows
through.

Two neighbouring pages: [bytecode.md](bytecode.md) is the file format, the
instruction set, the primitives and the command line;
[architecture.md](architecture.md) is which file of `vm/` does what.
[building.md](building.md) covers building the VM, including for Windows.

## Values and objects

A `Value` is 16 bytes: a tag and, beside it, an `int64_t`, a `uint64_t`, a
`double` or a pointer. That is so whatever the machine's pointer width, which
is why `Int`, `Word`, `Real` and the positions of files are the same on a
32-bit VM as on a 64-bit one.

These are immediate, and cost nothing to make: `unit`, `int`, `word`, `real`,
`char`, and a constructor with no argument (`nil`, `true`, `NONE`, and every
other nullary one, which is its tag as a number).

Everything else is an object in the heap: an 8-byte header -- kind, a
constructor tag and a length -- and a payload rounded up to a multiple of 16
bytes, at least 16. The smallest object is therefore 24 bytes, and a tuple of
*n* fields is 8 + 16*n* bytes. The kinds are a tuple (also a record and a
vector), a constructor with an argument, a closure, a string, a `ref`, an
array, an exception and an exception constructor.

A list cell is two objects: the pair of head and tail (40 bytes) and the
constructor around it (24), so 64 bytes a cell. `runevm --stats` and
`--count` report what a program really allocates.

An exception constructor is an object, and its identity is its address: that
is what makes two exceptions declared by the same code in two calls different
values, and it survives a collection and a `fork` (below).

## The heap

The collector is a Cheney two-space copier. Allocation is a bump of a pointer
in the current semispace; when a request does not fit, the live data is
copied into a new space and the old one is freed. The roots are the value
stack, the globals, the constants of the program, the closure of each frame
and the built-in exception constructors; from those the whole live graph is
copied, so anything unreachable disappears without being visited.

A collection moves every object. Nothing of that is visible to an SML
program: equality on `ref` and `array` is the identity the collector
maintains, not the address of the moment.

* The first semispace is 4 MiB, and `runevm --heap-size N` sets it (at least
  4096 bytes).
* After a collection the heap grows -- doubling -- until the live data is at
  most half of it and the request fits. A heap that would have to double past
  what a `size_t` can hold ends the run with `runevm: out of memory`.
* `runevm --stats` prints, at exit, the number of collections, the bytes
  allocated, the size of a semispace and the bytes live.
* `runevm --gc-stress N` collects before every *N*th allocation. With `N = 1`
  every allocation moves everything, which is how `make test-stress` finds a
  primitive that keeps a heap pointer in a C variable across an allocation.
* The processor time of the collector is measured around every collection and
  is what `Timer.checkGCTime` reports, so a program can tell its own time
  from the collector's.

Since a collection moves everything, C code inside the VM reads its arguments
from the value stack rather than holding them in variables; the pattern is in
[architecture.md](architecture.md).

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

`Int` and `Word` are 64 bits on every VM, whatever the pointer width, and
`Int` arithmetic raises `Overflow` where `Word` wraps. `Real` is an IEEE
double.

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
| Live data, 64-bit VM | the machine's memory | a collection holds both semispaces at once |
| Live data, 32-bit VM | about 512 MiB | `bin/runevm32.exe` is linked large-address-aware, which gives it 4 GiB of address space; without that it would be about half (an estimate: no test comes near) |

The ceiling of a 32-bit VM is lower than its address space because a
collection holds the old semispace and the new one at the same time. Running
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

Everything the VM needs from the operating system is behind `vm/sys.h`: time,
files, directories, descriptors, processes, sockets and the `Posix`
structure. `vm/sys_posix.c` implements it for POSIX systems, `vm/sys_win.c`
for Windows ([building.md](building.md)), and `vm/sys_none.c` fails every
call with `ENOSYS`, which keeps the rest of the VM ISO C99 with no platform
code in it (`make SYS=none`).

A call the platform cannot make answers `ENOSYS`, which the library turns
into `OS.SysErr`. Which those are is listed per platform in
[basis-compat.md](basis-compat.md) and, for Windows, in the `WINDOWS` lines
of `tests/basis/deviations.txt`.

`fork` is the one place where a platform lacks something the library cannot
do without. Windows has none, so `Posix.Process.fork` starts a second VM and
hands it this one's whole state -- the heap, the stacks, the program, the
open files, sockets and directory streams -- and the child carries on from
the `fork` as a copied process would (`vm/image.c`). `runevm --emulate-fork`
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
same run twice* and of *The heap*, `Runtime.profile` the difference of two of
them across a call, `Runtime.collect` a collection on demand, `Runtime.trace`
the frames of *Stacks, calls and exceptions* as data, `Runtime.save` the image
this page describes under *The system layer*, and `Runtime.same` the identity
the collector maintains. The page of the signature is
[generated/basis/sig/RUNTIME.md](generated/basis/sig/RUNTIME.md), and
[../examples/runtime](../examples/runtime) has a program for each part of it.

## Loading a program

`runevm` treats a `.rbc` file as untrusted input: every offset, length and
index is checked before anything runs, and a file that does not pass is
refused with a message and status 2; `tests/vm`, part of `make test`, is a
suite of crafted files and command lines that must all be refused so. A file
of another bytecode version is refused as well. There is no dynamic loading
afterwards: a program is one file, the basis library included.

The whole command line -- `--disasm`, `--trace`, `--stats`, `--count`,
`--gc-stress`, `--heap-size`, `--emulate-fork`, `--restore`, `--version` -- is described
in [bytecode.md](bytecode.md).

## A native program

`runeopt` ([plans/codegen.md](plans/codegen.md)) translates a `.rbc` into a
program for Linux on x86-64 that runs on the same runtime, linked into it:
the heap, the collector, the primitives and the system layer of this page are
the ones `runevm` has, and so are the value stack, the frames and the
handlers, which the translated code keeps where the interpreter keeps them.
So everything above holds for it: the layout of a value, when the collector
moves it, the limits, the counters of *The same run twice* -- the same numbers
for the same run, which `make test-native` checks for every program of the
suite -- the trace of a failure, the messages, which still begin `runevm:`,
and the images `Runtime.save` writes, which `runevm --restore` carries on.

What differs:

* The options of `runevm` (`--count`, `--stats`, `--heap-size`,
  `--gc-stress`) come from the environment variable `RUNEVM_OPTIONS`, after
  those the program was made with (`runeopt --options`), and the program takes
  the variable out of its environment.
* `CommandLine.name ()` is the name the program was started by.
* `Runtime.restore` raises `OS.SysErr`, and the program cannot carry on an
  image or be the child of a fork emulated by `--emulate-fork`; a fork is the
  system's own.
* The program carries its line table as DWARF: a debugger stops at a line of
  an SML source, and names a function by its name and its number.
