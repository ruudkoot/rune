# structure BinIO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; [Structures](../structures.md) &rsaquo; **BinIO**

|  |  |
| --- | --- |
| Signatures | [`BIN_IO`](../sig/BIN_IO.md), [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md) |
| Status | required |
| Members | 28 |
| Tests | 107 checks |
| Source | [lib/basis/binio.sml](../../../../lib/basis/binio.sml) |

## Synopsis

```sml
structure BinIO : BIN_IO
structure BinIO : IMPERATIVE_IO
```

BinIO: the imperative binary streams (signature BIN\_IO).

## Members

What each means is on [`BIN_IO`](../sig/BIN_IO.md) and [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`elem`](../sig/IMPERATIVE_IO.md#type-elem) | `Word8.word` |
| type | [`instream`](../sig/IMPERATIVE_IO.md#type-instream) | *a type of its own* |
| type | [`outstream`](../sig/IMPERATIVE_IO.md#type-outstream) | *a type of its own* |
| type | [`vector`](../sig/IMPERATIVE_IO.md#type-vector) | *a type of its own* |
| val | [`canInput`](../sig/IMPERATIVE_IO.md#val-caninput) | `instream * int -> int option` |
| val | [`closeIn`](../sig/IMPERATIVE_IO.md#val-closein) | `instream -> unit` |
| val | [`closeOut`](../sig/IMPERATIVE_IO.md#val-closeout) | `outstream -> unit` |
| val | [`endOfStream`](../sig/IMPERATIVE_IO.md#val-endofstream) | `instream -> bool` |
| val | [`flushOut`](../sig/IMPERATIVE_IO.md#val-flushout) | `outstream -> unit` |
| val | [`getInstream`](../sig/IMPERATIVE_IO.md#val-getinstream) | `instream -> StreamIO.instream` |
| val | [`getOutstream`](../sig/IMPERATIVE_IO.md#val-getoutstream) | `outstream -> StreamIO.outstream` |
| val | [`getPosOut`](../sig/IMPERATIVE_IO.md#val-getposout) | `outstream -> StreamIO.out_pos` |
| val | [`input`](../sig/IMPERATIVE_IO.md#val-input) | `instream -> vector` |
| val | [`input1`](../sig/IMPERATIVE_IO.md#val-input1) | `instream -> Word8.word option` |
| val | [`inputAll`](../sig/IMPERATIVE_IO.md#val-inputall) | `instream -> vector` |
| val | [`inputN`](../sig/IMPERATIVE_IO.md#val-inputn) | `instream * int -> vector` |
| val | [`lookahead`](../sig/IMPERATIVE_IO.md#val-lookahead) | `instream -> Word8.word option` |
| val | [`mkInstream`](../sig/IMPERATIVE_IO.md#val-mkinstream) | `StreamIO.instream -> instream` |
| val | [`mkOutstream`](../sig/IMPERATIVE_IO.md#val-mkoutstream) | `StreamIO.outstream -> outstream` |
| val | [`openAppend`](../sig/BIN_IO.md#val-openappend) | `string -> outstream` |
| val | [`openIn`](../sig/BIN_IO.md#val-openin) | `string -> instream` |
| val | [`openOut`](../sig/BIN_IO.md#val-openout) | `string -> outstream` |
| val | [`output`](../sig/IMPERATIVE_IO.md#val-output) | `outstream * vector -> unit` |
| val | [`output1`](../sig/IMPERATIVE_IO.md#val-output1) | `outstream * Word8.word -> unit` |
| val | [`setInstream`](../sig/IMPERATIVE_IO.md#val-setinstream) | `instream * StreamIO.instream -> unit` |
| val | [`setOutstream`](../sig/IMPERATIVE_IO.md#val-setoutstream) | `outstream * StreamIO.outstream -> unit` |
| val | [`setPosOut`](../sig/IMPERATIVE_IO.md#val-setposout) | `outstream * StreamIO.out_pos -> unit` |
| structure | [`StreamIO`](../str/BinIO.StreamIO.md) | [`STREAM_IO`](../sig/STREAM_IO.md) |

## Notes

### openOut

> **Implementation** `BinIO.openOut/bytes-are-characters`. A byte written
> here is the character of the same code read by [`TEXT_IO`](../sig/TEXT_IO.md), and the other
> way round: on POSIX nothing is translated between the two, for all 256
> values.

<details><summary>Other implementations (10)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **MLton, SML/NJ 110.99.9, Poly/ML** &mdash; getOutstream and setOutstream do not flush the stream ("flushes strm and returns the underlying StreamIO output stream", "flushes the stream underlying strm, and then assigns")
- **MLton** &mdash; the input1 that returns NONE leaves the stream before the end-of-stream; a second one consumes it
- **SML/NJ, SML/NJ 110.99.9** &mdash; input1 never moves past an end-of-stream
- **Poly/ML** &mdash; another reading of the specification: inputAll after an end-of-stream does not read what the file has gained; the test takes the reading of MLton and SML/NJ
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it: the example of stream-io.html ("abc", end-of-stream, "defg") gives "abc" and then "" for good
- **SML/NJ** &mdash; inputN (strm, \~1) raises Subscript, not Size
- **Poly/ML** &mdash; another reading of the specification: reports the qualified name ("TextIO.openIn"); the test takes the unqualified name, as MLton and SML/NJ do
- **MLton** &mdash; output1 on a closed stream raises Io with function "output"
- **SML/NJ 110.99.9** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

---

<sub>Generated by runedoc from lib/basis/binio.sml; do not edit.</sub>
