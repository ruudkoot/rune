# The Standard ML Basis Library

[How to read these pages](conventions.md) &middot; [the top-level environment](top-level.md) &middot; [structures and what they implement](structures.md) &middot; [exceptions](exceptions.md) &middot; [what is documented](coverage.md) &middot; index: [a](index/a.md) [b](index/b.md) [c](index/c.md) [d](index/d.md) [e](index/e.md) [f](index/f.md) [g](index/g.md) [h](index/h.md) [i](index/i.md) [j](index/j.md) [k](index/k.md) [l](index/l.md) [m](index/m.md) [n](index/n.md) [o](index/o.md) [p](index/p.md) [q](index/q.md) [r](index/r.md) [s](index/s.md) [t](index/t.md) [u](index/u.md) [v](index/v.md) [w](index/w.md) [x](index/x.md) [y](index/y.md) [z](index/z.md) [symbols](index/symbols.md)

## Text and characters

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`BOOL`](sig/BOOL.md) | Booleans: negation, and conversion to and from text. | required | 5 of 5 |
| [`CHAR`](sig/CHAR.md) | Characters: their codes and order, the classes they belong to, and their conversion to and from the text of SML and C character constants. | required | 35 of 35 |
| [`STRING_CVT`](sig/STRING_CVT.md) | The types and helpers of the conversions between values and text: the formats of `fmt`, the readers of `scan`. | required | 11 of 11 |

## Numbers

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`INT_INF`](sig/INT_INF.md) | Integers of arbitrary precision: everything [`INTEGER`](sig/INTEGER.md) has, and the operations that make sense only, or mostly, without a bound. | optional | 10 of 10 |

## Lists and options

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`LIST`](sig/LIST.md) | Polymorphic, immutable, singly linked lists. | required | 27 of 27 |
| [`OPTION`](sig/OPTION.md) | Optional values: a value that may be missing, and what a partial function returns instead of raising an exception. | required | 12 of 12 |

## The operating system

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`OS_IO`](sig/OS_IO.md) | Descriptors of open files, devices, pipes and sockets, and waiting until some of them are ready for input or output. | required | 26 of 26 |

## Not yet assigned to an area

| Signature |  | Status | Documented |
| --- | --- | --- | --- |
| [`ARRAY`](sig/ARRAY.md) | signature ARRAY, transcribed from <https://smlfamily.github.io/Basis/array.html> | required | 0 of 25 |
| [`ARRAY2`](sig/ARRAY2.md) | signature ARRAY2, transcribed from <https://smlfamily.github.io/Basis/array2.html> | required | 0 of 20 |
| [`ARRAY_SLICE`](sig/ARRAY_SLICE.md) | signature ARRAY\_SLICE, transcribed from <https://smlfamily.github.io/Basis/array-slice.html> | required | 0 of 26 |
| [`BIN_IO`](sig/BIN_IO.md) | signature BIN\_IO, transcribed from <https://smlfamily.github.io/Basis/bin-io.html> | required | 0 of 3 |
| [`BIT_FLAGS`](sig/BIT_FLAGS.md) | signature BIT\_FLAGS, transcribed from <https://smlfamily.github.io/Basis/bit-flags.html> | required | 0 of 9 |
| [`BYTE`](sig/BYTE.md) | signature BYTE, transcribed from <https://smlfamily.github.io/Basis/byte.html> | required | 0 of 7 |
| [`COMMAND_LINE`](sig/COMMAND_LINE.md) | signature COMMAND\_LINE, transcribed from <https://smlfamily.github.io/Basis/command-line.html> | required | 0 of 2 |
| [`DATE`](sig/DATE.md) | signature DATE, transcribed from <https://smlfamily.github.io/Basis/date.html> | required | 0 of 24 |
| [`GENERAL`](sig/GENERAL.md) | signature GENERAL, transcribed from <https://smlfamily.github.io/Basis/general.html> | required | 0 of 20 |
| [`GENERIC_SOCK`](sig/GENERIC_SOCK.md) | signature GENERIC\_SOCK, transcribed from <https://smlfamily.github.io/Basis/generic-sock.html> | required | 0 of 4 |
| [`IEEE_REAL`](sig/IEEE_REAL.md) | signature IEEE\_REAL, transcribed from <https://smlfamily.github.io/Basis/ieee-float.html> | required | 0 of 10 |
| [`IMPERATIVE_IO`](sig/IMPERATIVE_IO.md) | signature IMPERATIVE\_IO, transcribed from <https://smlfamily.github.io/Basis/imperative-io.html> | required | 0 of 25 |
| [`INET_SOCK`](sig/INET_SOCK.md) | signature INET\_SOCK, transcribed from <https://smlfamily.github.io/Basis/inet-sock.html> | required | 0 of 17 |
| [`INTEGER`](sig/INTEGER.md) | signature INTEGER, which the IntN structures are sealed with. | required | 0 of 30 |
| [`IO`](sig/IO.md) | signature IO, transcribed from <https://smlfamily.github.io/Basis/io.html> | required | 0 of 6 |
| [`LIST_PAIR`](sig/LIST_PAIR.md) | signature LIST\_PAIR, transcribed from <https://smlfamily.github.io/Basis/list-pair.html> | required | 0 of 15 |
| [`MATH`](sig/MATH.md) | signature MATH, transcribed from <https://smlfamily.github.io/Basis/math.html> | required | 0 of 18 |
| [`MONO_ARRAY`](sig/MONO_ARRAY.md) |  | required | 0 of 26 |
| [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | signature MONO\_ARRAY2, transcribed from <https://smlfamily.github.io/Basis/mono-array2.html> | required | 0 of 22 |
| [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) |  | required | 0 of 30 |
| [`MONO_VECTOR`](sig/MONO_VECTOR.md) | The signatures of the monomorphic vectors, arrays and their slices. | required | 0 of 22 |
| [`MONO_VECTOR_EQ`](sig/MONO_VECTOR_EQ.md) | The same with a vector that admits equality, for a family whose vector is a type of its own: WideCharVector, whose vector is the string of WideString, needs a type name so that wide string constants can be overloaded at it (`_overload string`), and strings are compared with =. | required | 0 of 22 |
| [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) |  | required | 0 of 26 |
| [`NET_HOST_DB`](sig/NET_HOST_DB.md) | signature NET\_HOST\_DB, transcribed from <https://smlfamily.github.io/Basis/net-host-db.html> | required | 0 of 14 |
| [`NET_PROT_DB`](sig/NET_PROT_DB.md) | signature NET\_PROT\_DB, transcribed from <https://smlfamily.github.io/Basis/prot-db.html> | required | 0 of 6 |
| [`NET_SERV_DB`](sig/NET_SERV_DB.md) | signature NET\_SERV\_DB, transcribed from <https://smlfamily.github.io/Basis/serv-db.html> | required | 0 of 7 |
| [`OS`](sig/OS.md) | signature OS, transcribed from <https://smlfamily.github.io/Basis/os.html> | required | 0 of 9 |
| [`OS_FILE_SYS`](sig/OS_FILE_SYS.md) | signature OS\_FILE\_SYS, transcribed from <https://smlfamily.github.io/Basis/os-file-sys.html> | required | 0 of 26 |
| [`OS_PATH`](sig/OS_PATH.md) | signature OS\_PATH, transcribed from <https://smlfamily.github.io/Basis/os-path.html> | required | 0 of 27 |
| [`OS_PROCESS`](sig/OS_PROCESS.md) | signature OS\_PROCESS, transcribed from <https://smlfamily.github.io/Basis/os-process.html> | required | 0 of 10 |
| [`PACK_REAL`](sig/PACK_REAL.md) | signature PACK\_REAL, transcribed from <https://smlfamily.github.io/Basis/pack-float.html> | required | 0 of 8 |
| [`PACK_WORD`](sig/PACK_WORD.md) | signature PACK\_WORD, transcribed from <https://smlfamily.github.io/Basis/pack-word.html> | required | 0 of 7 |
| [`POSIX`](sig/POSIX.md) | signature POSIX, transcribed from <https://smlfamily.github.io/Basis/posix.html> | required | 0 of 8 |
| [`POSIX_ERROR`](sig/POSIX_ERROR.md) | signature POSIX\_ERROR, transcribed from <https://smlfamily.github.io/Basis/posix-error.html> | required | 0 of 49 |
| [`POSIX_FILE_SYS`](sig/POSIX_FILE_SYS.md) | signature POSIX\_FILE\_SYS, transcribed from <https://smlfamily.github.io/Basis/posix-file-sys.html> | required | 0 of 91 |
| [`POSIX_IO`](sig/POSIX_IO.md) | signature POSIX\_IO, transcribed from <https://smlfamily.github.io/Basis/posix-io.html> | required | 0 of 41 |
| [`POSIX_PROCESS`](sig/POSIX_PROCESS.md) | signature POSIX\_PROCESS, transcribed from <https://smlfamily.github.io/Basis/posix-process.html> | required | 0 of 22 |
| [`POSIX_PROC_ENV`](sig/POSIX_PROC_ENV.md) | signature POSIX\_PROC\_ENV, transcribed from <https://smlfamily.github.io/Basis/posix-proc-env.html> | required | 0 of 30 |
| [`POSIX_SIGNAL`](sig/POSIX_SIGNAL.md) | signature POSIX\_SIGNAL, transcribed from <https://smlfamily.github.io/Basis/posix-signal.html> | required | 0 of 23 |
| [`POSIX_SYS_DB`](sig/POSIX_SYS_DB.md) | signature POSIX\_SYS\_DB, transcribed from <https://smlfamily.github.io/Basis/posix-sys-db.html> | required | 0 of 18 |
| [`POSIX_TTY`](sig/POSIX_TTY.md) | signature POSIX\_TTY, transcribed from <https://smlfamily.github.io/Basis/posix-tty.html> | required | 0 of 110 |
| [`PRIM_IO`](sig/PRIM_IO.md) | signature PRIM\_IO: the readers and writers under the stream layer. | required | 0 of 14 |
| [`REAL`](sig/REAL.md) | signature REAL, transcribed from <https://smlfamily.github.io/Basis/real.html> | required | 0 of 64 |
| [`SML90`](sig/SML90.md) | signature SML90. The page of the specification that defined it (sml90.html) is no longer at <https://smlfamily.github.io/Basis/>; transcribed from the signature of MLton's basis library, which follows it, in the order of the page. | required | 0 of 36 |
| [`SOCKET`](sig/SOCKET.md) | signature SOCKET, transcribed from <https://smlfamily.github.io/Basis/socket.html> | required | 0 of 93 |
| [`STREAM_IO`](sig/STREAM_IO.md) | signature STREAM\_IO: the functional streams. | required | 0 of 29 |
| [`STRING`](sig/STRING.md) | signature STRING, transcribed from <https://smlfamily.github.io/Basis/string.html> | required | 0 of 31 |
| [`SUBSTRING`](sig/SUBSTRING.md) | signature SUBSTRING, transcribed from <https://smlfamily.github.io/Basis/substring.html> | required | 0 of 39 |
| [`TEXT`](sig/TEXT.md) | signature TEXT, transcribed from <https://smlfamily.github.io/Basis/text.html> | required | 0 of 7 |
| [`TEXT_IO`](sig/TEXT_IO.md) | signature TEXT\_IO, transcribed from <https://smlfamily.github.io/Basis/text-io.html> and, for the part that it includes, from <https://smlfamily.github.io/Basis/imperative-io.html>. | required | 0 of 36 |
| [`TEXT_STREAM_IO`](sig/TEXT_STREAM_IO.md) | signature TEXT\_STREAM\_IO, transcribed from <https://smlfamily.github.io/Basis/text-stream-io.html> | required | 0 of 2 |
| [`TIME`](sig/TIME.md) | signature TIME, transcribed from <https://smlfamily.github.io/Basis/time.html> | required | 0 of 25 |
| [`TIMER`](sig/TIMER.md) | signature TIMER, transcribed from <https://smlfamily.github.io/Basis/timer.html> | required | 0 of 10 |
| [`UNIX`](sig/UNIX.md) | signature UNIX, transcribed from <https://smlfamily.github.io/Basis/unix.html> | required | 0 of 14 |
| [`UNIX_SOCK`](sig/UNIX_SOCK.md) | signature UNIX\_SOCK, transcribed from <https://smlfamily.github.io/Basis/unix-sock.html> | required | 0 of 14 |
| [`VECTOR`](sig/VECTOR.md) | signature VECTOR, transcribed from <https://smlfamily.github.io/Basis/vector.html> | required | 0 of 21 |
| [`VECTOR_SLICE`](sig/VECTOR_SLICE.md) | signature VECTOR\_SLICE, transcribed from <https://smlfamily.github.io/Basis/vector-slice.html> | required | 0 of 24 |
| [`WORD`](sig/WORD.md) | signature WORD | required | 0 of 38 |

## Functors

| Functor |  |
| --- | --- |
| [`PrimIO`](fun/PrimIO.md) | The optional functors of the specification that build the I/O stack for other element types: PrimIO, StreamIO and ImperativeIO, on the functors TextIO and BinIO are made of. |
| [`StreamIO`](fun/StreamIO.md) |  |
| [`ImperativeIO`](fun/ImperativeIO.md) |  |

---

<sub>Generated by runedoc; do not edit.</sub>
