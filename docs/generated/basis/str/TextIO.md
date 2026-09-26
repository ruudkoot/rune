# structure TextIO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; [Structures](../structures.md) &rsaquo; **TextIO**

|  |  |
| --- | --- |
| Signatures | [`TEXT_IO`](../sig/TEXT_IO.md), [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md) |
| Status | required |
| Members | 36 |
| Tests | 165 checks |
| Source | [lib/basis/textio.sml](../../../../lib/basis/textio.sml) |

## Synopsis

```sml
structure TextIO : TEXT_IO
structure TextIO : IMPERATIVE_IO
```

TextIO: the imperative text streams (signature TEXT\_IO).

## Members

What each means is on [`TEXT_IO`](../sig/TEXT_IO.md) and [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`elem`](../sig/TEXT_IO.md#type-elem) | `char` |
| type | [`instream`](../sig/TEXT_IO.md#type-instream) | *a type of its own* |
| type | [`outstream`](../sig/TEXT_IO.md#type-outstream) | *a type of its own* |
| type | [`vector`](../sig/TEXT_IO.md#type-vector) | `string` |
| val | [`canInput`](../sig/TEXT_IO.md#val-caninput) | `instream * int -> int option` |
| val | [`closeIn`](../sig/TEXT_IO.md#val-closein) | `instream -> unit` |
| val | [`closeOut`](../sig/TEXT_IO.md#val-closeout) | `outstream -> unit` |
| val | [`endOfStream`](../sig/TEXT_IO.md#val-endofstream) | `instream -> bool` |
| val | [`flushOut`](../sig/TEXT_IO.md#val-flushout) | `outstream -> unit` |
| val | [`getInstream`](../sig/TEXT_IO.md#val-getinstream) | `instream -> StreamIO.instream` |
| val | [`getOutstream`](../sig/TEXT_IO.md#val-getoutstream) | `outstream -> StreamIO.outstream` |
| val | [`getPosOut`](../sig/TEXT_IO.md#val-getposout) | `outstream -> StreamIO.out_pos` |
| val | [`input`](../sig/TEXT_IO.md#val-input) | `instream -> string` |
| val | [`input1`](../sig/TEXT_IO.md#val-input1) | `instream -> char option` |
| val | [`inputAll`](../sig/TEXT_IO.md#val-inputall) | `instream -> string` |
| val | [`inputLine`](../sig/TEXT_IO.md#val-inputline) | `instream -> string option` |
| val | [`inputN`](../sig/TEXT_IO.md#val-inputn) | `instream * int -> string` |
| val | [`lookahead`](../sig/TEXT_IO.md#val-lookahead) | `instream -> char option` |
| val | [`mkInstream`](../sig/TEXT_IO.md#val-mkinstream) | `StreamIO.instream -> instream` |
| val | [`mkOutstream`](../sig/TEXT_IO.md#val-mkoutstream) | `StreamIO.outstream -> outstream` |
| val | [`openAppend`](../sig/TEXT_IO.md#val-openappend) | `string -> outstream` |
| val | [`openIn`](../sig/TEXT_IO.md#val-openin) | `string -> instream` |
| val | [`openOut`](../sig/TEXT_IO.md#val-openout) | `string -> outstream` |
| val | [`openString`](../sig/TEXT_IO.md#val-openstring) | `string -> instream` |
| val | [`output`](../sig/TEXT_IO.md#val-output) | `outstream * string -> unit` |
| val | [`output1`](../sig/TEXT_IO.md#val-output1) | `outstream * char -> unit` |
| val | [`outputSubstr`](../sig/TEXT_IO.md#val-outputsubstr) | `outstream * substring -> unit` |
| val | [`print`](../sig/TEXT_IO.md#val-print) | `string -> unit` |
| val | [`scanStream`](../sig/TEXT_IO.md#val-scanstream) | `((StreamIO.instream -> (char * StreamIO.instream) option) -> StreamIO.instream -> ('a * StreamIO.instream) option) -> instream -> 'a option` |
| val | [`setInstream`](../sig/TEXT_IO.md#val-setinstream) | `instream * StreamIO.instream -> unit` |
| val | [`setOutstream`](../sig/TEXT_IO.md#val-setoutstream) | `outstream * StreamIO.outstream -> unit` |
| val | [`setPosOut`](../sig/TEXT_IO.md#val-setposout) | `outstream * StreamIO.out_pos -> unit` |
| val | [`stdErr`](../sig/TEXT_IO.md#val-stderr) | `outstream` |
| val | [`stdIn`](../sig/TEXT_IO.md#val-stdin) | `instream` |
| val | [`stdOut`](../sig/TEXT_IO.md#val-stdout) | `outstream` |
| structure | [`StreamIO`](../str/TextIO.StreamIO.md) | [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md), [`STREAM_IO`](../sig/STREAM_IO.md) |

## Notes

### flushOut

> **Reading** `TextIO.flushOut/closed-is-a-no-op`. Through [`STREAM_IO`](../sig/STREAM_IO.md) ("a
> no-op on terminated streams", and a closed stream is terminated too),
> flushing a closed outstream does nothing rather than raising.

### inputLine

> **Reading** `TextIO.inputLine/does-not-pass-the-end-of-stream`. An
> [`inputLine`](../sig/TEXT_IO.md#val-inputline) that gives `NONE` does not consume the end of stream it
> found -- [`TEXT_STREAM_IO.inputLine`](../sig/TEXT_STREAM_IO.md#val-inputline) returns no stream in that case, so
> there is none to move on to -- and it keeps giving `NONE` even after the
> file has grown. Poly/ML reads on there.

### openOut

> **Implementation** `TextIO.openOut/buffer-mode`. The mode is `LINE_BUF`
> when the file is a terminal and `BLOCK_BUF` otherwise, as the
> specification asks; but the stream itself holds nothing back. The VM
> keeps the block and flushes every file at exit, so what a program writes
> with [`print`](../sig/TEXT_IO.md#val-print) and what it writes through a stream reach the file in the
> order it wrote them.

### output

> **Implementation** `TextIO.output/no-translation`. On the POSIX systems the
> suite runs on, a text file holds exactly the characters written to it:
> no newline is translated and no character is dropped, for all 256
> of them.

### outputSubstr

> **Reading** `TextIO.outputSubstr/Io-function-is-output`. It is "equivalent
> to [`output`](../sig/TEXT_IO.md#val-output)", so the `function` of an [`IO.Io`](../sig/IO.md#exn-io) it raises is `"output"`, as
> MLton and Poly/ML report it. SML/NJ reports `"outputSubstr"`.

### scanStream

> **Reading** `TextIO.scanStream/moves-only-on-success`. By the
> implementation the page gives, the stream is moved to where the scanner
> stopped when it returns `SOME`, and not at all when it returns `NONE`,
> whatever the scanner read while trying.

<details><summary>Other implementations (14)</summary>

- **Poly/ML** &mdash; characters buffered before closeIn are still read after it
- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **MLton, SML/NJ 110.99.9, Poly/ML** &mdash; getOutstream and setOutstream do not flush the stream ("flushes strm and returns the underlying StreamIO output stream", "flushes the stream underlying strm, and then assigns")
- **MLton** &mdash; the input1 that returns NONE leaves the stream before the end-of-stream; a second one consumes it
- **SML/NJ, SML/NJ 110.99.9** &mdash; input1 never moves past an end-of-stream
- **Poly/ML** &mdash; another reading of the specification: inputAll after an end-of-stream does not read what the file has gained; the test takes the reading of MLton and SML/NJ
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it: the example of stream-io.html ("abc", end-of-stream, "defg") gives "abc" and then "" for good
- **Poly/ML** &mdash; another reading of the specification: inputLine that returned NONE reads on when the file has grown; the test takes the STREAM\_IO model, as MLton and SML/NJ do
- **SML/NJ** &mdash; inputN (strm, \~1) raises Subscript, not Size
- **Poly/ML** &mdash; another reading of the specification: reports the qualified name ("TextIO.openIn"); the test takes the unqualified name, as MLton and SML/NJ do
- **SML/NJ** &mdash; inputAll (openString "") raises Io {cause = Div, ...}
- **MLton** &mdash; output1 on a closed stream raises Io with function "output"
- **SML/NJ** &mdash; another reading of the specification: reports function "outputSubstr"; the test takes outputSubstr to be "equivalent to" output, as MLton and Poly/ML do
- **SML/NJ 110.99.9** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

---

<sub>Generated by runedoc from lib/basis/textio.sml; do not edit.</sub>
