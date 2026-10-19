# structure WideTextIO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; [Structures](../structures.md) &rsaquo; **WideTextIO**

|  |  |
| --- | --- |
| Signatures | [`TEXT_IO`](../sig/TEXT_IO.md), [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md) |
| Status | optional |
| Members | 37 |
| Tests | 63 checks |
| Source | [lib/basis/widetextio.sml](../../../../lib/basis/widetextio.sml) |

## Synopsis

```sml
structure WideTextIO : TEXT_IO where type StreamIO.vector = WideCharVector.vector where type StreamIO.elem = WideChar.char where type StreamIO.substring = WideSubstring.substring where type StreamIO.reader = WideTextPrimIO.reader where type StreamIO.writer = WideTextPrimIO.writer where type StreamIO.pos = WideTextPrimIO.pos
structure WideTextIO : IMPERATIVE_IO
```

WideTextIO (optional in the specification): the imperative streams of the
wide character, as TextIO is of `char`: [`TEXT_IO`](../sig/TEXT_IO.md) over [`WideString.string`](../sig/STRING.md#type-string)
and [`WideChar.char`](../sig/CHAR.md#type-char), with the readers and writers of [`WideTextPrimIO`](../str/WideTextPrimIO.md)
(the deviation `TEXT_IO/generic`, which makes that signature one of both).

> **Implementation** `WideTextIO/files-hold-utf-8`. The specification names no
> encoding, so a stream of [`WideTextIO`](WideTextIO.md) is a stream of [`TextIO`](../str/TextIO.md) encoded in
> UTF-8: one byte for a code point below 128, up to four above it. What is
> not UTF-8 raises [`IO.Io`](../sig/IO.md#exn-io) with the cause `Fail "UTF-8"`. On input that is a
> byte sequence that the Unicode Standard's Table 3-7 does not list: an
> overlong form, a surrogate, a value past 0x10FFFF, a lead byte C0, C1 or
> F5 to FF, a continuation byte where a sequence begins, a sequence cut
> short. On output it is a surrogate, which a [`WideChar.char`](../sig/CHAR.md#type-char) may be (it
> holds every code point) and UTF-8 does not hold. A stream made with
> [`mkInstream`](../sig/TEXT_IO.md#val-mkinstream) over a reader of one's own carries wide characters as they
> are, surrogates included, without an encoding. No host has a [`WideTextIO`](WideTextIO.md)
> to compare with.

> **Limitation** `WideTextIO/file-streams-have-no-positions`. The reader and
> the writer of a file of wide characters have no positions, no `ioDesc`,
> no operations that do not block, and neither [`canInput`](../sig/TEXT_IO.md#val-caninput) nor `avail`: a
> position in the file is one of bytes and not of characters. Their
> `chunkSize` is 4096 characters, as that of a file of [`TextIO`](../str/TextIO.md) is 4096
> bytes.

## Members

What each means is on [`TEXT_IO`](../sig/TEXT_IO.md) and [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`elem`](../sig/TEXT_IO.md#type-elem) | `RuneWideChar.char` |
| type | [`instream`](../sig/TEXT_IO.md#type-instream) | *a type of its own* |
| type | [`outstream`](../sig/TEXT_IO.md#type-outstream) | *a type of its own* |
| type | [`substring`](../sig/TEXT_IO.md#type-substring) | `WideCharVectorSlice.slice` |
| type | [`vector`](../sig/TEXT_IO.md#type-vector) | `WideString.string` |
| val | [`canInput`](../sig/TEXT_IO.md#val-caninput) | `instream * int -> int option` |
| val | [`closeIn`](../sig/TEXT_IO.md#val-closein) | `instream -> unit` |
| val | [`closeOut`](../sig/TEXT_IO.md#val-closeout) | `outstream -> unit` |
| val | [`endOfStream`](../sig/TEXT_IO.md#val-endofstream) | `instream -> bool` |
| val | [`flushOut`](../sig/TEXT_IO.md#val-flushout) | `outstream -> unit` |
| val | [`getInstream`](../sig/TEXT_IO.md#val-getinstream) | `instream -> StreamIO.instream` |
| val | [`getOutstream`](../sig/TEXT_IO.md#val-getoutstream) | `outstream -> StreamIO.outstream` |
| val | [`getPosOut`](../sig/TEXT_IO.md#val-getposout) | `outstream -> StreamIO.out_pos` |
| val | [`input`](../sig/TEXT_IO.md#val-input) | `instream -> WideString.string` |
| val | [`input1`](../sig/TEXT_IO.md#val-input1) | `instream -> RuneWideChar.char option` |
| val | [`inputAll`](../sig/TEXT_IO.md#val-inputall) | `instream -> WideString.string` |
| val | [`inputLine`](../sig/TEXT_IO.md#val-inputline) | `instream -> WideString.string option` |
| val | [`inputN`](../sig/TEXT_IO.md#val-inputn) | `instream * int -> WideString.string` |
| val | [`lookahead`](../sig/TEXT_IO.md#val-lookahead) | `instream -> RuneWideChar.char option` |
| val | [`mkInstream`](../sig/TEXT_IO.md#val-mkinstream) | `StreamIO.instream -> instream` |
| val | [`mkOutstream`](../sig/TEXT_IO.md#val-mkoutstream) | `StreamIO.outstream -> outstream` |
| val | [`openAppend`](../sig/TEXT_IO.md#val-openappend) | `string -> outstream` |
| val | [`openIn`](../sig/TEXT_IO.md#val-openin) | `string -> instream` |
| val | [`openOut`](../sig/TEXT_IO.md#val-openout) | `string -> outstream` |
| val | [`openString`](../sig/TEXT_IO.md#val-openstring) | `WideString.string -> instream` |
| val | [`output`](../sig/TEXT_IO.md#val-output) | `outstream * WideString.string -> unit` |
| val | [`output1`](../sig/TEXT_IO.md#val-output1) | `outstream * RuneWideChar.char -> unit` |
| val | [`outputSubstr`](../sig/TEXT_IO.md#val-outputsubstr) | `outstream * WideCharVectorSlice.slice -> unit` |
| val | [`print`](../sig/TEXT_IO.md#val-print) | `WideString.string -> unit` |
| val | [`scanStream`](../sig/TEXT_IO.md#val-scanstream) | `((StreamIO.instream -> (RuneWideChar.char * StreamIO.instream) option) -> StreamIO.instream -> ('a * StreamIO.instream) option) -> instream -> 'a option` |
| val | [`setInstream`](../sig/TEXT_IO.md#val-setinstream) | `instream * StreamIO.instream -> unit` |
| val | [`setOutstream`](../sig/TEXT_IO.md#val-setoutstream) | `outstream * StreamIO.outstream -> unit` |
| val | [`setPosOut`](../sig/TEXT_IO.md#val-setposout) | `outstream * StreamIO.out_pos -> unit` |
| val | [`stdErr`](../sig/TEXT_IO.md#val-stderr) | `outstream` |
| val | [`stdIn`](../sig/TEXT_IO.md#val-stdin) | `instream` |
| val | [`stdOut`](../sig/TEXT_IO.md#val-stdout) | `outstream` |
| structure | [`StreamIO`](../str/WideTextIO.StreamIO.md) | [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md), [`STREAM_IO`](../sig/STREAM_IO.md) |

<details><summary>Other implementations (5)</summary>

- **MLton, SML/NJ, Poly/ML, MLKit** &mdash; getOutstream and setOutstream do not flush the stream ("flushes strm and returns the underlying StreamIO output stream", "flushes the stream underlying strm, and then assigns")
- **SML/NJ** &mdash; input1 never moves past an end-of-stream
- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it: the example of stream-io.html ("abc", end-of-stream, "defg") gives "abc" and then "" for good
- **SML/NJ** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

---

<sub>Generated by runedoc from lib/basis/widetextio.sml; do not edit.</sub>
