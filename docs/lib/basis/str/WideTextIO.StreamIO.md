# structure WideTextIO.StreamIO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; [Structures](../structures.md) &rsaquo; **WideTextIO.StreamIO**

|  |  |
| --- | --- |
| Signatures | [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md), [`STREAM_IO`](../sig/STREAM_IO.md) |
| Status | required |
| Members | 32 |
| Tests | 116 checks |
| Source | [lib/basis/widetextio.sml](../../../../lib/basis/widetextio.sml) |

## Synopsis

```sml
structure WideTextIO.StreamIO : TEXT_STREAM_IO where type vector = WideCharVector.vector where type elem = WideChar.char where type substring = WideSubstring.substring where type reader = WideTextPrimIO.reader where type writer = WideTextPrimIO.writer where type pos = WideTextPrimIO.pos
structure WideTextIO.StreamIO : STREAM_IO
```

WideTextIO.StreamIO: the functional streams of wide text under
[`WideTextIO`](../str/WideTextIO.md), with the operations on lines and substrings of
TEXT\_STREAM\_IO.

## Members

What each means is on [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md) and [`STREAM_IO`](../sig/STREAM_IO.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`elem`](../sig/STREAM_IO.md#type-elem) | `RuneWideChar.char` |
| type | [`instream`](../sig/STREAM_IO.md#type-instream) | *a type of its own* |
| type | [`out_pos`](../sig/STREAM_IO.md#type-out_pos) | *a type of its own* |
| type | [`outstream`](../sig/STREAM_IO.md#type-outstream) | *a type of its own* |
| type | [`pos`](../sig/STREAM_IO.md#type-pos) | `RuneWideTextPos.pos` |
| type | [`reader`](../sig/STREAM_IO.md#type-reader) | `WideTextPrimIO.reader` |
| type | [`substring`](../sig/TEXT_STREAM_IO.md#type-substring) | `WideCharVectorSlice.slice` |
| type | [`vector`](../sig/STREAM_IO.md#type-vector) | `WideString.string` |
| type | [`writer`](../sig/STREAM_IO.md#type-writer) | `WideTextPrimIO.writer` |
| val | [`canInput`](../sig/STREAM_IO.md#val-caninput) | `instream * int -> int option` |
| val | [`closeIn`](../sig/STREAM_IO.md#val-closein) | `instream -> unit` |
| val | [`closeOut`](../sig/STREAM_IO.md#val-closeout) | `outstream -> unit` |
| val | [`endOfStream`](../sig/STREAM_IO.md#val-endofstream) | `instream -> bool` |
| val | [`filePosIn`](../sig/STREAM_IO.md#val-fileposin) | `instream -> RuneWideTextPos.pos` |
| val | [`filePosOut`](../sig/STREAM_IO.md#val-fileposout) | `out_pos -> RuneWideTextPos.pos` |
| val | [`flushOut`](../sig/STREAM_IO.md#val-flushout) | `outstream -> unit` |
| val | [`getBufferMode`](../sig/STREAM_IO.md#val-getbuffermode) | `outstream -> IO.buffer_mode` |
| val | [`getPosOut`](../sig/STREAM_IO.md#val-getposout) | `outstream -> out_pos` |
| val | [`getReader`](../sig/STREAM_IO.md#val-getreader) | `instream -> WideTextPrimIO.reader * WideString.string` |
| val | [`getWriter`](../sig/STREAM_IO.md#val-getwriter) | `outstream -> WideTextPrimIO.writer * IO.buffer_mode` |
| val | [`input`](../sig/STREAM_IO.md#val-input) | `instream -> WideString.string * instream` |
| val | [`input1`](../sig/STREAM_IO.md#val-input1) | `instream -> (RuneWideChar.char * instream) option` |
| val | [`inputAll`](../sig/STREAM_IO.md#val-inputall) | `instream -> WideString.string * instream` |
| val | [`inputLine`](../sig/TEXT_STREAM_IO.md#val-inputline) | `instream -> (WideString.string * instream) option` |
| val | [`inputN`](../sig/STREAM_IO.md#val-inputn) | `instream * int -> WideString.string * instream` |
| val | [`mkInstream`](../sig/STREAM_IO.md#val-mkinstream) | `WideTextPrimIO.reader * WideString.string -> instream` |
| val | [`mkOutstream`](../sig/STREAM_IO.md#val-mkoutstream) | `WideTextPrimIO.writer * IO.buffer_mode -> outstream` |
| val | [`output`](../sig/STREAM_IO.md#val-output) | `outstream * WideString.string -> unit` |
| val | [`output1`](../sig/STREAM_IO.md#val-output1) | `outstream * RuneWideChar.char -> unit` |
| val | [`outputSubstr`](../sig/TEXT_STREAM_IO.md#val-outputsubstr) | `outstream * WideCharVectorSlice.slice -> unit` |
| val | [`setBufferMode`](../sig/STREAM_IO.md#val-setbuffermode) | `outstream * IO.buffer_mode -> unit` |
| val | [`setPosOut`](../sig/STREAM_IO.md#val-setposout) | `out_pos -> outstream` |

<details><summary>Other implementations (18)</summary>

- **MLton** &mdash; canInput on a stream whose elements input has already read answers SOME 0, which means end-of-stream (the noBlock predicate of stream-io.html)
- **SML/NJ** &mdash; canInput on a stream whose reader would block answers SOME 0 (end-of-stream), not NONE, and the elements it reads ahead are lost to the stream
- **MLton, Poly/ML, MLKit** &mdash; closeIn of a stream that getReader truncated does not close the reader ("one can close a truncated or terminated string")
- **MLton, MLKit** &mdash; closeOut of a stream that getWriter terminated does not close the writer ("one can close a truncated or terminated string")
- **SML/NJ** &mdash; getReader of a closed or truncated stream raises nothing
- **SML/NJ** &mdash; getWriter of a closed stream raises nothing
- **Poly/ML** &mdash; input lets the exception of the reader through instead of raising Io with it as the cause
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it: the example of stream-io.html ("abc", end-of-stream, "defg") gives "abc" and then "" for good
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it as the definition by input does
- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **SML/NJ** &mdash; inputN (strm, \~1) raises Subscript, not Size
- **SML/NJ** &mdash; inputN that finds fewer than n elements before an end-of-stream leaves the stream before it, where inputAll leaves it past it (allAndN)
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it, so that inputN and inputAll disagree (allAndN)
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it
- **SML/NJ** &mdash; output and output1 on a stream that getWriter terminated go on writing instead of raising Io
- **MLton** &mdash; output1 lets the exception of the writer through instead of raising Io with it as the cause (output raises Io)
- **MLKit** &mdash; output1 on an unbuffered stream lets the exception of the writer through instead of raising Io with it as the cause (output raises Io)
- **SML/NJ** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

---

<sub>Generated by runedoc from lib/basis/widetextio.sml; do not edit.</sub>
