# The Standard ML Basis Library

[How to read these pages](conventions.md) &middot; [the top-level environment](top-level.md) &middot; [structures and what they implement](structures.md) &middot; [exceptions](exceptions.md) &middot; [readings of the specification](readings.md) &middot; [what is documented](coverage.md) &middot; index: [a](index/a.md) [b](index/b.md) [c](index/c.md) [d](index/d.md) [e](index/e.md) [f](index/f.md) [g](index/g.md) [h](index/h.md) [i](index/i.md) [j](index/j.md) [k](index/k.md) [l](index/l.md) [m](index/m.md) [n](index/n.md) [o](index/o.md) [p](index/p.md) [q](index/q.md) [r](index/r.md) [s](index/s.md) [t](index/t.md) [u](index/u.md) [v](index/v.md) [w](index/w.md) [x](index/x.md) [y](index/y.md) [z](index/z.md) [symbols](index/symbols.md)

## Sequences

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`ARRAY`](sig/ARRAY.md) | Arrays: mutable sequences of a fixed length, of any element type. | required | 25 of 25 |
| [`ARRAY2`](sig/ARRAY2.md) | Two-dimensional arrays: mutable rectangles of elements, indexed by a row and a column. | optional | 20 of 20 |
| [`ARRAY_SLICE`](sig/ARRAY_SLICE.md) | A stretch of an array, without a copy of it: a base array and a start and a length inside it. | required | 26 of 26 |
| [`MONO_ARRAY`](sig/MONO_ARRAY.md) | Mutable sequences of one element type. | required | 26 of 26 |
| [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | Two-dimensional arrays of one element type, as [`ARRAY2`](sig/ARRAY2.md) describes them for any element type. | optional | 22 of 22 |
| [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | A stretch of an array of one element type, without a copy of it. | required | 30 of 30 |
| [`MONO_VECTOR`](sig/MONO_VECTOR.md) | The sequences of one element type: vectors, arrays and their slices, as [`VECTOR`](sig/VECTOR.md), [`ARRAY`](sig/ARRAY.md), [`VECTOR_SLICE`](sig/VECTOR_SLICE.md) and [`ARRAY_SLICE`](sig/ARRAY_SLICE.md) describe them for any element type. | required | 22 of 22 |
| [`MONO_VECTOR_EQ`](sig/MONO_VECTOR_EQ.md) | The same as [`MONO_VECTOR`](sig/MONO_VECTOR.md), with a vector type that admits equality. | extension | 22 of 22 |
| [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | A stretch of a vector of one element type, without a copy of it. | required | 26 of 26 |
| [`VECTOR`](sig/VECTOR.md) | Vectors: immutable sequences of a fixed length, of any element type. | required | 21 of 21 |
| [`VECTOR_SLICE`](sig/VECTOR_SLICE.md) | A stretch of a vector, without a copy of it: a base vector and a start and a length inside it. | required | 24 of 24 |

## Input and output

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`BIN_IO`](sig/BIN_IO.md) | Binary files: the imperative streams of bytes, with the ways of opening a file. | required | 3 of 3 |
| [`IMPERATIVE_IO`](sig/IMPERATIVE_IO.md) | Streams that remember where they are: a cell holding a functional stream, which every operation replaces by what it left. | required | 25 of 25 |
| [`IO`](sig/IO.md) | What the whole of the I/O stack shares: the exception it raises and the ways a stream may hold output back. | required | 6 of 6 |
| [`PRIM_IO`](sig/PRIM_IO.md) | The layer under the streams: a reader is a source of elements, a writer a sink for them, and both are records of the operations they happen to have. | required | 14 of 14 |
| [`STREAM_IO`](sig/STREAM_IO.md) | Streams as values: reading gives the elements and the stream that is left, so a stream can be kept, read twice, and read from again where it was. | required | 29 of 29 |
| [`TEXT_IO`](sig/TEXT_IO.md) | Text files and the standard streams: the imperative streams of characters, with the ways of opening a file. | required | 36 of 36 |
| [`TEXT_STREAM_IO`](sig/TEXT_STREAM_IO.md) | The functional streams of [`STREAM_IO`](sig/STREAM_IO.md) where the elements are characters, with the two operations that only text has: reading a line and writing a substring. | required | 2 of 2 |

## Text and characters

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`BOOL`](sig/BOOL.md) | Booleans: negation, and conversion to and from text. | required | 5 of 5 |
| [`BYTE`](sig/BYTE.md) | Between bytes and characters: the same eight bits read as a [`Word8.word`](sig/WORD.md#type-word) and as a `char`. | required | 7 of 7 |
| [`CHAR`](sig/CHAR.md) | Characters: their codes and order, the classes they belong to, and their conversion to and from the text of SML and C character constants. | required | 35 of 35 |
| [`STRING`](sig/STRING.md) | Strings: immutable sequences of characters, with the operations that take them apart, put them together, compare them and write them as the text of a string constant. | required | 31 of 31 |
| [`STRING_CVT`](sig/STRING_CVT.md) | The types and helpers of the conversions between values and text: the formats of `fmt`, the readers of `scan`. | required | 11 of 11 |
| [`SUBSTRING`](sig/SUBSTRING.md) | A stretch of a string, without a copy of it: a base string and a start and a length inside it. | required | 39 of 39 |
| [`TEXT`](sig/TEXT.md) | The structures of one kind of text, gathered so that their types can be named as one: characters, strings, substrings and the vectors and arrays of characters, with the constraints that tie them together. | required | 7 of 7 |

## The operating system

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`COMMAND_LINE`](sig/COMMAND_LINE.md) | The name of the program and the arguments it was given. | required | 2 of 2 |
| [`DATE`](sig/DATE.md) | A moment as a person writes it down: a year, a month, a day and a time of day, in some time zone. | required | 24 of 24 |
| [`OS`](sig/OS.md) | The operating system: its errors, its file system, its paths, its processes and its I/O descriptors, gathered into one structure. | required | 9 of 9 |
| [`OS_FILE_SYS`](sig/OS_FILE_SYS.md) | The file system: reading directories, moving about in them, and asking what a file is and when it changed. | required | 26 of 26 |
| [`OS_IO`](sig/OS_IO.md) | Descriptors of open files, devices, pipes and sockets, and waiting until some of them are ready for input or output. | required | 26 of 26 |
| [`OS_PATH`](sig/OS_PATH.md) | Paths as text: taking them apart, putting them together, and nothing else. | required | 27 of 27 |
| [`OS_PROCESS`](sig/OS_PROCESS.md) | The process itself: its environment, the commands it runs, and how it ends. | required | 10 of 10 |
| [`TIME`](sig/TIME.md) | A length of time, and a point in time counted from a fixed reference. | required | 25 of 25 |
| [`TIMER`](sig/TIMER.md) | Stopwatches: how much processor time and how much wall-clock time have passed since a timer was started. | required | 10 of 10 |

## The language

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`GENERAL`](sig/GENERAL.md) | The types, exceptions and values of the top-level environment that belong to no other structure. | required | 20 of 20 |

## Numbers

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`IEEE_REAL`](sig/IEEE_REAL.md) | The parts of IEEE 754 arithmetic that are not about one real number: the rounding mode, the classes a number can belong to, and an exact decimal form to convert through. | optional | 10 of 10 |
| [`INTEGER`](sig/INTEGER.md) | Integers of a fixed precision, with arithmetic that raises [`Overflow`](sig/GENERAL.md#exn-overflow) rather than wrapping round. | required | 30 of 30 |
| [`INT_INF`](sig/INT_INF.md) | Integers of arbitrary precision: everything [`INTEGER`](sig/INTEGER.md) has, and the operations that make sense only, or mostly, without a bound. | optional | 10 of 10 |
| [`MATH`](sig/MATH.md) | The elementary functions of a real type: roots, the trigonometric and hyperbolic functions, exponentials and logarithms. | required | 18 of 18 |
| [`PACK_REAL`](sig/PACK_REAL.md) | Reading and writing a real number in a vector or an array of bytes, in its IEEE 754 encoding and a fixed byte order. | optional | 8 of 8 |
| [`PACK_WORD`](sig/PACK_WORD.md) | Reading and writing a word in a vector or an array of bytes, in a fixed byte order. | optional | 7 of 7 |
| [`REAL`](sig/REAL.md) | Floating-point numbers: IEEE 754 arithmetic, the numbers that are not ordinary (the infinities, the NaNs and the negative zero), and the conversions to and from integers and text. | required | 64 of 64 |
| [`WORD`](sig/WORD.md) | Words: integers of a fixed number of bits, without a sign, whose arithmetic wraps round instead of overflowing, and which can be taken apart bit by bit. | required | 38 of 38 |

## Lists and options

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`LIST`](sig/LIST.md) | Polymorphic, immutable, singly linked lists. | required | 27 of 27 |
| [`LIST_PAIR`](sig/LIST_PAIR.md) | Two lists walked side by side: pairing, and the traversals that take a function of an element of each. | required | 15 of 15 |
| [`OPTION`](sig/OPTION.md) | Optional values: a value that may be missing, and what a partial function returns instead of raising an exception. | required | 12 of 12 |

## Not yet assigned to an area

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`BIT_FLAGS`](sig/BIT_FLAGS.md) | signature BIT\_FLAGS, transcribed from <https://smlfamily.github.io/Basis/bit-flags.html> | required | 0 of 9 |
| [`GENERIC_SOCK`](sig/GENERIC_SOCK.md) | signature GENERIC\_SOCK, transcribed from <https://smlfamily.github.io/Basis/generic-sock.html> | required | 0 of 4 |
| [`INET_SOCK`](sig/INET_SOCK.md) | signature INET\_SOCK, transcribed from <https://smlfamily.github.io/Basis/inet-sock.html> | required | 0 of 17 |
| [`NET_HOST_DB`](sig/NET_HOST_DB.md) | signature NET\_HOST\_DB, transcribed from <https://smlfamily.github.io/Basis/net-host-db.html> | required | 0 of 14 |
| [`NET_PROT_DB`](sig/NET_PROT_DB.md) | signature NET\_PROT\_DB, transcribed from <https://smlfamily.github.io/Basis/prot-db.html> | required | 0 of 6 |
| [`NET_SERV_DB`](sig/NET_SERV_DB.md) | signature NET\_SERV\_DB, transcribed from <https://smlfamily.github.io/Basis/serv-db.html> | required | 0 of 7 |
| [`POSIX`](sig/POSIX.md) | signature POSIX, transcribed from <https://smlfamily.github.io/Basis/posix.html> | required | 0 of 8 |
| [`POSIX_ERROR`](sig/POSIX_ERROR.md) | signature POSIX\_ERROR, transcribed from <https://smlfamily.github.io/Basis/posix-error.html> | required | 0 of 49 |
| [`POSIX_FILE_SYS`](sig/POSIX_FILE_SYS.md) | signature POSIX\_FILE\_SYS, transcribed from <https://smlfamily.github.io/Basis/posix-file-sys.html> | required | 0 of 91 |
| [`POSIX_IO`](sig/POSIX_IO.md) | signature POSIX\_IO, transcribed from <https://smlfamily.github.io/Basis/posix-io.html> | required | 0 of 41 |
| [`POSIX_PROCESS`](sig/POSIX_PROCESS.md) | signature POSIX\_PROCESS, transcribed from <https://smlfamily.github.io/Basis/posix-process.html> | required | 0 of 22 |
| [`POSIX_PROC_ENV`](sig/POSIX_PROC_ENV.md) | signature POSIX\_PROC\_ENV, transcribed from <https://smlfamily.github.io/Basis/posix-proc-env.html> | required | 0 of 30 |
| [`POSIX_SIGNAL`](sig/POSIX_SIGNAL.md) | signature POSIX\_SIGNAL, transcribed from <https://smlfamily.github.io/Basis/posix-signal.html> | required | 0 of 23 |
| [`POSIX_SYS_DB`](sig/POSIX_SYS_DB.md) | signature POSIX\_SYS\_DB, transcribed from <https://smlfamily.github.io/Basis/posix-sys-db.html> | required | 0 of 18 |
| [`POSIX_TTY`](sig/POSIX_TTY.md) | signature POSIX\_TTY, transcribed from <https://smlfamily.github.io/Basis/posix-tty.html> | required | 0 of 110 |
| [`SML90`](sig/SML90.md) | signature SML90. The page of the specification that defined it (sml90.html) is no longer at <https://smlfamily.github.io/Basis/>; transcribed from the signature of MLton's basis library, which follows it, in the order of the page. | required | 0 of 36 |
| [`SOCKET`](sig/SOCKET.md) | signature SOCKET, transcribed from <https://smlfamily.github.io/Basis/socket.html> | required | 0 of 93 |
| [`UNIX`](sig/UNIX.md) | signature UNIX, transcribed from <https://smlfamily.github.io/Basis/unix.html> | required | 0 of 14 |
| [`UNIX_SOCK`](sig/UNIX_SOCK.md) | signature UNIX\_SOCK, transcribed from <https://smlfamily.github.io/Basis/unix-sock.html> | required | 0 of 14 |

## Functors

| Functor |  |
| --- | --- |
| [`PrimIO`](fun/PrimIO.md) | The optional functors of the specification that build the I/O stack for other element types: PrimIO, StreamIO and ImperativeIO, on the functors TextIO and BinIO are made of. |
| [`StreamIO`](fun/StreamIO.md) |  |
| [`ImperativeIO`](fun/ImperativeIO.md) |  |

---

<sub>Generated by runedoc; do not edit.</sub>
