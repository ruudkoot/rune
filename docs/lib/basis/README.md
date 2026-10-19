# The Standard ML Basis Library

The library every Standard ML program starts with: lists and options,
sequences, text, numbers, input and output, and the operating system.

These pages describe Rune's Basis Library. They are generated from the
signatures the library is built from, so what stands here is what the
compiler enforces; where the specification is silent, ambiguous or wrong, a
note on the member says how Rune reads it, and the page of readings,
linked below, collects them all.

A signature says what a member means, and a structure says what it is here.
So [`LIST`](sig/LIST.md) describes what [`List`](str/List.md) does, [`INTEGER`](sig/INTEGER.md) what [`Int`](str/Int.md), [`Int32`](str/Int32.md),
[`LargeInt`](str/IntInf.md) and [`Position`](str/Position.md) all do, and [`MONO_VECTOR`](sig/MONO_VECTOR.md) what [`Word8Vector`](str/Word8Vector.md) and
[`CharVector`](str/CharVector.md) do, while the page of a structure shows its members with the
types it gives them: [`Word8Vector.sub`](sig/MONO_VECTOR.md#val-sub) is `vector * int -> Word8.word` where
[`MONO_VECTOR`](sig/MONO_VECTOR.md) can only write `vector * int -> elem`. Follow a member to the
signature to read what it means, and a structure to its own page to see what
it is. A name that needs no structure in front of it, such as [`hd`](sig/LIST.md#val-hd) or
`print`, is on the page of the top-level environment, also linked below.

Three things are worth knowing before reading further. Sequences are indexed
from 0, and a slice is a stretch of one that costs nothing to pass. A
function that can fail either returns an [`option`](sig/OPTION.md#type-option) or raises an exception, and
which it does is said for every one. And the optional parts of the library,
the wide characters, the sized integers, [`POSIX`](sig/POSIX.md) and the sockets, are marked
as optional, because a program that uses them is not bound to run on every
implementation. Every optional part is there, [`Windows`](str/Windows.md) too, whose calls of
the system answer on Windows only.

[How to read these pages](../conventions.md) &middot; [the top-level environment](top-level.md) &middot; [the structures](structures.md) &middot; [exceptions](exceptions.md) &middot; [what depends on what](depends.md) &middot; [types that are one type](types.md) &middot; [readings of the specification](readings.md) &middot; [what is documented](coverage.md) &middot; index: [a](index/a.md) [b](index/b.md) [c](index/c.md) [d](index/d.md) [e](index/e.md) [f](index/f.md) [g](index/g.md) [h](index/h.md) [i](index/i.md) [j](index/j.md) [k](index/k.md) [l](index/l.md) [m](index/m.md) [n](index/n.md) [o](index/o.md) [p](index/p.md) [q](index/q.md) [r](index/r.md) [s](index/s.md) [t](index/t.md) [u](index/u.md) [v](index/v.md) [w](index/w.md) [x](index/x.md) [y](index/y.md) [z](index/z.md) [symbols](index/symbols.md)

## Sequences

| Signature |  | Status |
| --- | --- | --- |
| [`ARRAY`](sig/ARRAY.md) | Arrays: mutable sequences of a fixed length, of any element type. | required |
| [`ARRAY2`](sig/ARRAY2.md) | Two-dimensional arrays: mutable rectangles of elements, indexed by a row and a column. | optional |
| [`ARRAY_SLICE`](sig/ARRAY_SLICE.md) | A stretch of an array, without a copy of it: a base array and a start and a length inside it. | required |
| [`MONO_ARRAY`](sig/MONO_ARRAY.md) | Mutable sequences of one element type. | required |
| [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | Two-dimensional arrays of one element type, as [`ARRAY2`](sig/ARRAY2.md) describes them for any element type. | optional |
| [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | A stretch of an array of one element type, without a copy of it. | required |
| [`MONO_VECTOR`](sig/MONO_VECTOR.md) | The sequences of one element type: vectors, arrays and their slices, as [`VECTOR`](sig/VECTOR.md), [`ARRAY`](sig/ARRAY.md), [`VECTOR_SLICE`](sig/VECTOR_SLICE.md) and [`ARRAY_SLICE`](sig/ARRAY_SLICE.md) describe them for any element type. | required |
| [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | A stretch of a vector of one element type, without a copy of it. | required |
| [`VECTOR`](sig/VECTOR.md) | Vectors: immutable sequences of a fixed length, of any element type. | required |
| [`VECTOR_SLICE`](sig/VECTOR_SLICE.md) | A stretch of a vector, without a copy of it: a base vector and a start and a length inside it. | required |

## Input and output

| Signature |  | Status |
| --- | --- | --- |
| [`BIN_IO`](sig/BIN_IO.md) | Binary files: the imperative streams of bytes, with the ways of opening a file. | required |
| [`IMPERATIVE_IO`](sig/IMPERATIVE_IO.md) | Streams that remember where they are: a cell holding a functional stream, which every operation replaces by what it left. | required |
| [`IO`](sig/IO.md) | What the whole of the I/O stack shares: the exception it raises and the ways a stream may hold output back. | required |
| [`PRIM_IO`](sig/PRIM_IO.md) | The layer under the streams: a reader is a source of elements, a writer a sink for them, and both are records of the operations they happen to have. | required |
| [`STREAM_IO`](sig/STREAM_IO.md) | Streams as values: reading gives the elements and the stream that is left, so a stream can be kept, read twice, and read from again where it was. | required |
| [`TEXT_IO`](sig/TEXT_IO.md) | Text files and the standard streams: the imperative streams of characters, with the ways of opening a file. | required |
| [`TEXT_STREAM_IO`](sig/TEXT_STREAM_IO.md) | The functional streams of [`STREAM_IO`](sig/STREAM_IO.md) where the elements are characters, with the two operations that only text has: reading a line and writing a substring. | required |

## The operating system

| Signature |  | Status |
| --- | --- | --- |
| [`BIT_FLAGS`](sig/BIT_FLAGS.md) | A set of flags held as the bits of a word: what every collection of system flags in [`POSIX`](sig/POSIX.md) has in common. | optional |
| [`COMMAND_LINE`](sig/COMMAND_LINE.md) | The name of the program and the arguments it was given. | required |
| [`DATE`](sig/DATE.md) | A moment as a person writes it down: a year, a month, a day and a time of day, in some time zone. | required |
| [`GENERIC_SOCK`](sig/GENERIC_SOCK.md) | Making a socket of any family the system has, when the family is not known until the program runs. | optional |
| [`INET6_SOCK`](sig/INET6_SOCK.md) | Sockets of the Internet protocol version 6, as [`INET_SOCK`](sig/INET_SOCK.md) describes them for version 4. | extension |
| [`INET_SOCK`](sig/INET_SOCK.md) | Sockets of the internet family: an address is a host and a port. | optional |
| [`NET_HOST_DB`](sig/NET_HOST_DB.md) | The host database: turning a host name into an address, and back. | optional |
| [`NET_PROT_DB`](sig/NET_PROT_DB.md) | The protocol database: turning the name of a network protocol into its number, and back. | optional |
| [`NET_SERV_DB`](sig/NET_SERV_DB.md) | The service database: turning the name of a network service into its port, and back. | optional |
| [`OS`](sig/OS.md) | The operating system: its errors, its file system, its paths, its processes and its I/O descriptors, gathered into one structure. | required |
| [`OS_FILE_SYS`](sig/OS_FILE_SYS.md) | The file system: reading directories, moving about in them, and asking what a file is and when it changed. | required |
| [`OS_IO`](sig/OS_IO.md) | Descriptors of open files, devices, pipes and sockets, and waiting until some of them are ready for input or output. | required |
| [`OS_PATH`](sig/OS_PATH.md) | Paths as text: taking them apart, putting them together, and nothing else. | required |
| [`OS_PROCESS`](sig/OS_PROCESS.md) | The process itself: its environment, the commands it runs, and how it ends. | required |
| [`POSIX`](sig/POSIX.md) | The POSIX interface: the system calls of a Unix-like system, gathered into eight substructures. | optional |
| [`POSIX_ERROR`](sig/POSIX_ERROR.md) | The conditions the system reports when a call fails, and their names. | optional |
| [`POSIX_FILE_SYS`](sig/POSIX_FILE_SYS.md) | Files and directories as POSIX has them: opening them, linking and removing them, and reading and setting what the system records about them. | optional |
| [`POSIX_IO`](sig/POSIX_IO.md) | File descriptors: reading and writing them, duplicating them, positioning them, locking them, and turning them into readers and writers. | optional |
| [`POSIX_PROCESS`](sig/POSIX_PROCESS.md) | Processes: making them, replacing them, waiting for them and ending them. | optional |
| [`POSIX_PROC_ENV`](sig/POSIX_PROC_ENV.md) | The process's own identity: who it is, who owns it, which group and session it belongs to, and what its environment holds. | optional |
| [`POSIX_SIGNAL`](sig/POSIX_SIGNAL.md) | The signals a process may be sent, by name. | optional |
| [`POSIX_SYS_DB`](sig/POSIX_SYS_DB.md) | The password and group databases: turning a user or group name into a number, and back. | optional |
| [`POSIX_TTY`](sig/POSIX_TTY.md) | Terminals: their modes, their speeds and the characters that control them. | optional |
| [`SOCKET`](sig/SOCKET.md) | Sockets: connections between processes, on one machine or across a network. | optional |
| [`TIME`](sig/TIME.md) | A length of time, and a point in time counted from a fixed reference. | required |
| [`TIMER`](sig/TIMER.md) | Stopwatches: how much processor time and how much wall-clock time have passed since a timer was started. | required |
| [`UNIX`](sig/UNIX.md) | Running another program and talking to it: a child process with a pipe each way. | optional |
| [`UNIX_SOCK`](sig/UNIX_SOCK.md) | Sockets of the Unix family: an address is a path in the file system, and the connection never leaves the machine. | optional |
| [`WINDOWS`](sig/WINDOWS.md) | The operating system Windows: the registry, the configuration of the machine, dynamic data exchange, programs started with a pipe each way, and the codes a process ends with. | optional |

## Text and characters

| Signature |  | Status |
| --- | --- | --- |
| [`BOOL`](sig/BOOL.md) | Booleans: negation, and conversion to and from text. | required |
| [`BYTE`](sig/BYTE.md) | Between bytes and characters: the same eight bits read as a [`Word8.word`](sig/WORD.md#type-word) and as a `char`. | required |
| [`CHAR`](sig/CHAR.md) | Characters: their codes and order, the classes they belong to, and their conversion to and from the text of SML and C character constants. | required |
| [`STRING`](sig/STRING.md) | Strings: immutable sequences of characters, with the operations that take them apart, put them together, compare them and write them as the text of a string constant. | required |
| [`STRING_CVT`](sig/STRING_CVT.md) | The types and helpers of the conversions between values and text: the formats of `fmt`, the readers of `scan`. | required |
| [`SUBSTRING`](sig/SUBSTRING.md) | A stretch of a string, without a copy of it: a base string and a start and a length inside it. | required |
| [`TEXT`](sig/TEXT.md) | The structures of one kind of text, gathered so that their types can be named as one: characters, strings, substrings and the vectors and arrays of characters, with the constraints that tie them together. | required |

## The runtime

| Signature |  | Status |
| --- | --- | --- |
| [`COMPILER`](sig/COMPILER.md) | What a program can ask of the compiler it runs beside: in the REPL (`rune-repl`, docs/repl.md) the compiler is in the same program as the code it compiled, and a program compiles more of itself with `use`. | extension |
| [`DISPLAY`](sig/DISPLAY.md) | What a program shows beside what it prints: an output in several forms \-- text, HTML, an image -- of which the front shows the best it can (docs/kernel.md). | extension |
| [`DYNAMIC`](sig/DYNAMIC.md) | Dynamic modules: units of code that a program loads while it runs (docs/units.md, Dynamic modules). | extension |
| [`REPL`](sig/REPL.md) | What a program can ask of the REPL it runs in: its commands, as functions, for init files, scripts and HOL4 (docs/repl.md, Commands). | extension |
| [`RUNTIME`](sig/RUNTIME.md) | What a program can ask about the machine it is running on: how much work it has done, and how much memory that took. | extension |
| [`SUBPROCESS`](sig/SUBPROCESS.md) | Programs started as children that a runner of tests supervises (docs/plans/unit-testing.md, M2): in a directory of their own, in a process group (a job on Windows) that can be ended as one, under limits, with the signals at their default actions, and waited for with what they cost. | extension |
| [`TERMINAL`](sig/TERMINAL.md) | The terminal of a program that edits what is typed at it, as a line editor does: the window's size and its changes, keys read one by one with a time limit, and a terminal put back as it was whatever way the program ends (docs/plans/repl.md, D4 and D5). | extension |

## The language

| Signature |  | Status |
| --- | --- | --- |
| [`GENERAL`](sig/GENERAL.md) | The types, exceptions and values of the top-level environment that belong to no other structure. | required |
| [`SML90`](sig/SML90.md) | What the 1990 library looked like, kept so that old programs still run. | optional |

## Numbers

| Signature |  | Status |
| --- | --- | --- |
| [`IEEE_REAL`](sig/IEEE_REAL.md) | The parts of IEEE 754 arithmetic that are not about one real number: the rounding mode, the classes a number can belong to, and an exact decimal form to convert through. | required |
| [`INTEGER`](sig/INTEGER.md) | Integers of a fixed precision, with arithmetic that raises [`Overflow`](sig/GENERAL.md#exn-overflow) rather than wrapping round. | required |
| [`INT_INF`](sig/INT_INF.md) | Integers of arbitrary precision: everything [`INTEGER`](sig/INTEGER.md) has, and the operations that make sense only, or mostly, without a bound. | optional |
| [`MATH`](sig/MATH.md) | The elementary functions of a real type: roots, the trigonometric and hyperbolic functions, exponentials and logarithms. | required |
| [`PACK_REAL`](sig/PACK_REAL.md) | Reading and writing a real number in a vector or an array of bytes, in its IEEE 754 encoding and a fixed byte order. | optional |
| [`PACK_WORD`](sig/PACK_WORD.md) | Reading and writing a word in a vector or an array of bytes, in a fixed byte order. | optional |
| [`REAL`](sig/REAL.md) | Floating-point numbers: IEEE 754 arithmetic, the numbers that are not ordinary (the infinities, the NaNs and the negative zero), and the conversions to and from integers and text. | required |
| [`WORD`](sig/WORD.md) | Words: integers of a fixed number of bits, without a sign, whose arithmetic wraps round instead of overflowing, and which can be taken apart bit by bit. | required |

## Lists and options

| Signature |  | Status |
| --- | --- | --- |
| [`LIST`](sig/LIST.md) | Polymorphic, immutable, singly linked lists. | required |
| [`LIST_PAIR`](sig/LIST_PAIR.md) | Two lists walked side by side: pairing, and the traversals that take a function of an element of each. | required |
| [`OPTION`](sig/OPTION.md) | Optional values: a value that may be missing, and what a partial function returns instead of raising an exception. | required |

## Functors

| Functor |  |
| --- | --- |
| [`PrimIO`](fun/PrimIO.md) | Readers and writers of a new element type: the [`PRIM_IO`](sig/PRIM_IO.md) of it, built from the vectors, arrays and slices of that type. |
| [`StreamIO`](fun/StreamIO.md) | Functional streams over a [`PRIM_IO`](sig/PRIM_IO.md) of a new element type: the [`STREAM_IO`](sig/STREAM_IO.md) of it. |
| [`ImperativeIO`](fun/ImperativeIO.md) | Imperative streams over a [`STREAM_IO`](sig/STREAM_IO.md) of a new element type: what [`TEXT_IO`](sig/TEXT_IO.md) and [`BIN_IO`](sig/BIN_IO.md) are for characters and bytes. |

---

<sub>Generated by runedoc; do not edit.</sub>
