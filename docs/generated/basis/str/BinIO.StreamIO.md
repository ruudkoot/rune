# structure BinIO.StreamIO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; [Structures](../structures.md) &rsaquo; **BinIO.StreamIO**

|  |  |
| --- | --- |
| Signature | [`STREAM_IO`](../sig/STREAM_IO.md) |
| Status | required |
| Members | 29 |
| Tests | 99 checks |
| Source | [lib/basis/binio.sml](../../../../lib/basis/binio.sml) |

## Synopsis

```sml
structure BinIO.StreamIO : STREAM_IO where type vector = Word8Vector.vector where type elem = Word8.word where type reader = BinPrimIO.reader where type writer = BinPrimIO.writer where type pos = Position.int
```

"For binary streams, LINE\_BUF mode should be treated as a synonym for
BLOCK\_BUF": no element is a newline.

## Members

What each means is on [`STREAM_IO`](../sig/STREAM_IO.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`elem`](../sig/STREAM_IO.md#type-elem) | `Word8.word` |
| type | [`instream`](../sig/STREAM_IO.md#type-instream) | *a type of its own* |
| type | [`out_pos`](../sig/STREAM_IO.md#type-out_pos) | *a type of its own* |
| type | [`outstream`](../sig/STREAM_IO.md#type-outstream) | *a type of its own* |
| type | [`pos`](../sig/STREAM_IO.md#type-pos) | `int` |
| type | [`reader`](../sig/STREAM_IO.md#type-reader) | *a type of its own* |
| type | [`vector`](../sig/STREAM_IO.md#type-vector) | *a type of its own* |
| type | [`writer`](../sig/STREAM_IO.md#type-writer) | *a type of its own* |
| val | [`canInput`](../sig/STREAM_IO.md#val-caninput) | `instream * int -> int option` |
| val | [`closeIn`](../sig/STREAM_IO.md#val-closein) | `instream -> unit` |
| val | [`closeOut`](../sig/STREAM_IO.md#val-closeout) | `outstream -> unit` |
| val | [`endOfStream`](../sig/STREAM_IO.md#val-endofstream) | `instream -> bool` |
| val | [`filePosIn`](../sig/STREAM_IO.md#val-fileposin) | `instream -> int` |
| val | [`filePosOut`](../sig/STREAM_IO.md#val-fileposout) | `out_pos -> int` |
| val | [`flushOut`](../sig/STREAM_IO.md#val-flushout) | `outstream -> unit` |
| val | [`getBufferMode`](../sig/STREAM_IO.md#val-getbuffermode) | `outstream -> IO.buffer_mode` |
| val | [`getPosOut`](../sig/STREAM_IO.md#val-getposout) | `outstream -> out_pos` |
| val | [`getReader`](../sig/STREAM_IO.md#val-getreader) | `instream -> reader * vector` |
| val | [`getWriter`](../sig/STREAM_IO.md#val-getwriter) | `outstream -> writer * IO.buffer_mode` |
| val | [`input`](../sig/STREAM_IO.md#val-input) | `instream -> vector * instream` |
| val | [`input1`](../sig/STREAM_IO.md#val-input1) | `instream -> (Word8.word * instream) option` |
| val | [`inputAll`](../sig/STREAM_IO.md#val-inputall) | `instream -> vector * instream` |
| val | [`inputN`](../sig/STREAM_IO.md#val-inputn) | `instream * int -> vector * instream` |
| val | [`mkInstream`](../sig/STREAM_IO.md#val-mkinstream) | `reader * vector -> instream` |
| val | [`mkOutstream`](../sig/STREAM_IO.md#val-mkoutstream) | `writer * IO.buffer_mode -> outstream` |
| val | [`output`](../sig/STREAM_IO.md#val-output) | `outstream * vector -> unit` |
| val | [`output1`](../sig/STREAM_IO.md#val-output1) | `outstream * Word8.word -> unit` |
| val | [`setBufferMode`](../sig/STREAM_IO.md#val-setbuffermode) | `outstream * IO.buffer_mode -> unit` |
| val | [`setPosOut`](../sig/STREAM_IO.md#val-setposout) | `out_pos -> outstream` |

<details><summary>Other implementations (18)</summary>

- **MLton** &mdash; canInput on a stream whose elements input has already read answers SOME 0, which means end-of-stream (the noBlock predicate of stream-io.html)
- **SML/NJ 110.99.9** &mdash; canInput on a stream whose reader would block answers SOME 0 (end-of-stream), not NONE, and the elements it reads ahead are lost to the stream
- **MLton, Poly/ML** &mdash; closeIn of a stream that getReader truncated does not close the reader ("one can close a truncated or terminated string")
- **MLton** &mdash; closeOut of a stream that getWriter terminated does not close the writer ("one can close a truncated or terminated string")
- **MLton, SML/NJ 110.99.9** &mdash; filePosIn of a truncated stream raises nothing
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
- **SML/NJ 110.99.9** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

---

<sub>Generated by runedoc from lib/basis/binio.sml; do not edit.</sub>
