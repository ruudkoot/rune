# structure TextIO.StreamIO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; [Structures](../structures.md) &rsaquo; **TextIO.StreamIO**

|  |  |
| --- | --- |
| Signatures | [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md), [`STREAM_IO`](../sig/STREAM_IO.md) |
| Status | required |
| Members | 31 |
| Tests | 117 checks |
| Source | [lib/basis/textio.sml](../../../../lib/basis/textio.sml) |

## Synopsis

```sml
structure TextIO.StreamIO : TEXT_STREAM_IO where type reader = TextPrimIO.reader where type writer = TextPrimIO.writer where type pos = TextPrimIO.pos
structure TextIO.StreamIO : STREAM_IO
```

TEXT\_STREAM\_IO: STREAM\_IO and the operations on lines and substrings.

## Members

What each means is on [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md) and [`STREAM_IO`](../sig/STREAM_IO.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`elem`](../sig/STREAM_IO.md#type-elem) | `char` |
| type | [`instream`](../sig/STREAM_IO.md#type-instream) | *a type of its own* |
| type | [`out_pos`](../sig/STREAM_IO.md#type-out_pos) | *a type of its own* |
| type | [`outstream`](../sig/STREAM_IO.md#type-outstream) | *a type of its own* |
| type | [`pos`](../sig/STREAM_IO.md#type-pos) | *a type of its own* |
| type | [`reader`](../sig/STREAM_IO.md#type-reader) | *a type of its own* |
| type | [`vector`](../sig/STREAM_IO.md#type-vector) | `string` |
| type | [`writer`](../sig/STREAM_IO.md#type-writer) | *a type of its own* |
| val | [`canInput`](../sig/STREAM_IO.md#val-caninput) | `instream * int -> int option` |
| val | [`closeIn`](../sig/STREAM_IO.md#val-closein) | `instream -> unit` |
| val | [`closeOut`](../sig/STREAM_IO.md#val-closeout) | `outstream -> unit` |
| val | [`endOfStream`](../sig/STREAM_IO.md#val-endofstream) | `instream -> bool` |
| val | [`filePosIn`](../sig/STREAM_IO.md#val-fileposin) | `instream -> pos` |
| val | [`filePosOut`](../sig/STREAM_IO.md#val-fileposout) | `out_pos -> pos` |
| val | [`flushOut`](../sig/STREAM_IO.md#val-flushout) | `outstream -> unit` |
| val | [`getBufferMode`](../sig/STREAM_IO.md#val-getbuffermode) | `outstream -> IO.buffer_mode` |
| val | [`getPosOut`](../sig/STREAM_IO.md#val-getposout) | `outstream -> out_pos` |
| val | [`getReader`](../sig/STREAM_IO.md#val-getreader) | `instream -> reader * string` |
| val | [`getWriter`](../sig/STREAM_IO.md#val-getwriter) | `outstream -> writer * IO.buffer_mode` |
| val | [`input`](../sig/STREAM_IO.md#val-input) | `instream -> string * instream` |
| val | [`input1`](../sig/STREAM_IO.md#val-input1) | `instream -> (char * instream) option` |
| val | [`inputAll`](../sig/STREAM_IO.md#val-inputall) | `instream -> string * instream` |
| val | [`inputLine`](../sig/TEXT_STREAM_IO.md#val-inputline) | `instream -> (string * instream) option` |
| val | [`inputN`](../sig/STREAM_IO.md#val-inputn) | `instream * int -> string * instream` |
| val | [`mkInstream`](../sig/STREAM_IO.md#val-mkinstream) | `reader * string -> instream` |
| val | [`mkOutstream`](../sig/STREAM_IO.md#val-mkoutstream) | `writer * IO.buffer_mode -> outstream` |
| val | [`output`](../sig/STREAM_IO.md#val-output) | `outstream * string -> unit` |
| val | [`output1`](../sig/STREAM_IO.md#val-output1) | `outstream * char -> unit` |
| val | [`outputSubstr`](../sig/TEXT_STREAM_IO.md#val-outputsubstr) | `outstream * substring -> unit` |
| val | [`setBufferMode`](../sig/STREAM_IO.md#val-setbuffermode) | `outstream * IO.buffer_mode -> unit` |
| val | [`setPosOut`](../sig/STREAM_IO.md#val-setposout) | `out_pos -> outstream` |

## Notes

### inputLine

> **Reading** `TextIO.StreamIO.inputLine/last-line-without-a-newline`. A last
> line that runs into an end of stream gets a newline appended, so that
> every line returned ends in one, and the stream returned is past that
> end of stream. At an end of stream itself it is `NONE`.

<details><summary>Other implementations (20)</summary>

- **MLton** &mdash; canInput on a stream whose elements input has already read answers SOME 0, which means end-of-stream (the noBlock predicate of stream-io.html)
- **SML/NJ 110.99.9** &mdash; canInput on a stream whose reader would block answers SOME 0 (end-of-stream), not NONE, and the elements it reads ahead are lost to the stream
- **MLton, Poly/ML** &mdash; closeIn of a stream that getReader truncated does not close the reader ("one can close a truncated or terminated string")
- **MLton** &mdash; closeOut of a stream that getWriter terminated does not close the writer ("one can close a truncated or terminated string")
- **MLton, SML/NJ 110.99.9** &mdash; filePosIn of a truncated stream raises nothing
- **SML/NJ 110.99.9** &mdash; openAppend makes an unbuffered stream ("When opening a stream for writing, the stream will be block buffered by default")
- **SML/NJ 110.99.9** &mdash; getReader of a closed or truncated stream raises nothing
- **SML/NJ 110.99.9** &mdash; getWriter of a closed stream raises nothing
- **Poly/ML** &mdash; input lets the exception of the reader through instead of raising Io with it as the cause
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it: the example of stream-io.html ("abc", end-of-stream, "defg") gives "abc" and then "" for good
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it as the definition by input does
- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **SML/NJ** &mdash; inputN (strm, \~1) raises Subscript, not Size
- **SML/NJ 110.99.9** &mdash; inputN that finds fewer than n elements before an end-of-stream leaves the stream before it, where inputAll leaves it past it (allAndN)
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it, so that inputN and inputAll disagree (allAndN)
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it
- **SML/NJ 110.99.9** &mdash; output and output1 on a stream that getWriter terminated go on writing instead of raising Io
- **MLton** &mdash; output1 lets the exception of the writer through instead of raising Io with it as the cause (output raises Io)
- **Poly/ML** &mdash; outputSubstr does not flush a line-buffered stream at a newline, which output does ("equivalent to: output (strm, Substring.string ss)")
- **SML/NJ 110.99.9** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

---

<sub>Generated by runedoc from lib/basis/textio.sml; do not edit.</sub>
