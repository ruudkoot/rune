# signature TEXT_IO

[The Standard ML Basis Library](../README.md) &rsaquo; **TEXT_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 36 entries documented |
| Tests | 233 checks of 35 entries |
| Source | [lib/basis/sig\_text\_io.sml](../../../../lib/basis/sig_text_io.sml) |

## Synopsis

```sml
signature TEXT_IO
structure TextIO : TEXT_IO
```

| Implementation |  | Source |
| --- | --- | --- |
| `TextIO` | TextIO: the imperative text streams (signature TEXT\_IO). | [lib/basis/textio.sml](../../../../lib/basis/textio.sml) |

signature TEXT\_IO, transcribed from
<https://smlfamily.github.io/Basis/text-io.html> and, for the part that it
includes, from <https://smlfamily.github.io/Basis/imperative-io.html>.

The page writes `include IMPERATIVE_IO` and then respecifies the
substructure StreamIO as a TEXT\_STREAM\_IO, which is not valid SML; it says
that the meaning is "a structure matching TEXT\_IO also matches
IMPERATIVE\_IO and has a substructure StreamIO that matches TEXT\_STREAM\_IO".
That is what is written here: the substructure first, with its
constraints, then the rest of IMPERATIVE\_IO in full, then the members of
TEXT\_IO. (tests/basis/textio\_full\_sig.sml also matches TextIO against
IMPERATIVE\_IO.) The substructure has TEXT\_STREAM\_IO of
tests/basis/spec-sigs/TEXT\_STREAM\_IO.sml, which includes STREAM\_IO of
STREAM\_IO.sml; a test that uses this file uses those first.

The optional WideTextIO is left out.

## Contents

[The members of IMPERATIVE\_IO](#the-members-of-imperativeio) &middot;
[The members of TEXT\_IO](#the-members-of-textio)

## Interface

<pre>
signature TEXT_IO =
sig
  structure <a href="#str-streamio">StreamIO</a> : TEXT_STREAM_IO
    where type reader = TextPrimIO.reader
    where type writer = TextPrimIO.writer
    where type pos = TextPrimIO.pos

  type <a href="#type-vector">vector</a> = StreamIO.vector
  type <a href="#type-elem">elem</a> = StreamIO.elem

  type <a href="#type-instream">instream</a>
  type <a href="#type-outstream">outstream</a>

  val <a href="#val-input">input</a> : instream -&gt; vector
  val <a href="#val-input1">input1</a> : instream -&gt; elem option
  val <a href="#val-inputn">inputN</a> : instream * int -&gt; vector
  val <a href="#val-inputall">inputAll</a> : instream -&gt; vector
  val <a href="#val-caninput">canInput</a> : instream * int -&gt; int option
  val <a href="#val-lookahead">lookahead</a> : instream -&gt; elem option
  val <a href="#val-closein">closeIn</a> : instream -&gt; unit
  val <a href="#val-endofstream">endOfStream</a> : instream -&gt; bool

  val <a href="#val-output">output</a> : outstream * vector -&gt; unit
  val <a href="#val-output1">output1</a> : outstream * elem -&gt; unit
  val <a href="#val-flushout">flushOut</a> : outstream -&gt; unit
  val <a href="#val-closeout">closeOut</a> : outstream -&gt; unit

  val <a href="#val-mkinstream">mkInstream</a> : StreamIO.instream -&gt; instream
  val <a href="#val-getinstream">getInstream</a> : instream -&gt; StreamIO.instream
  val <a href="#val-setinstream">setInstream</a> : instream * StreamIO.instream -&gt; unit

  val <a href="#val-mkoutstream">mkOutstream</a> : StreamIO.outstream -&gt; outstream
  val <a href="#val-getoutstream">getOutstream</a> : outstream -&gt; StreamIO.outstream
  val <a href="#val-setoutstream">setOutstream</a> : outstream * StreamIO.outstream -&gt; unit
  val <a href="#val-getposout">getPosOut</a> : outstream -&gt; StreamIO.out_pos
  val <a href="#val-setposout">setPosOut</a> : outstream * StreamIO.out_pos -&gt; unit

  val <a href="#val-inputline">inputLine</a> : instream -&gt; string option
  val <a href="#val-outputsubstr">outputSubstr</a> : outstream * substring -&gt; unit
  val <a href="#val-openin">openIn</a> : string -&gt; instream
  val <a href="#val-openout">openOut</a> : string -&gt; outstream
  val <a href="#val-openappend">openAppend</a> : string -&gt; outstream
  val <a href="#val-openstring">openString</a> : string -&gt; instream

  val <a href="#val-stdin">stdIn</a> : instream
  val <a href="#val-stdout">stdOut</a> : outstream
  val <a href="#val-stderr">stdErr</a> : outstream

  val <a href="#val-print">print</a> : string -&gt; unit
  val <a href="#val-scanstream">scanStream</a> : ((Char.char, StreamIO.instream) StringCvt.reader
                    -&gt; ('a, StreamIO.instream) StringCvt.reader)
                   -&gt; instream -&gt; 'a option
end
</pre>

### <a name="str-streamio"></a>`StreamIO`

```sml
structure StreamIO : TEXT_STREAM_IO
  where type reader = TextPrimIO.reader
  where type writer = TextPrimIO.writer
  where type pos = TextPrimIO.pos
```

A substructure: its members are described on the page of [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md).

## The members of IMPERATIVE\_IO

### <a name="type-vector"></a>`vector`

```sml
type vector = StreamIO.vector
```

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `is-string`

</details>

### <a name="type-elem"></a>`elem`

```sml
type elem = StreamIO.elem
```

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `is-char`

</details>

### <a name="type-instream"></a>`instream`

```sml
type instream
```

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `two-on-one-file`

</details>

### <a name="type-outstream"></a>`outstream`

```sml
type outstream
```

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `two-files`

</details>

### <a name="val-input"></a>`input`

```sml
val input : instream -> vector
```

<details><summary>Tests (8)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `at-least-one-character` &middot; `empty-file` &middot; `pieces-make-the-file` &middot; `empty-again-at-end-of-stream` &middot; `large` &middot; `after-inputLine` &middot; `empty-after-input-and-inputAll` &middot; `closed-stream`

</details>

### <a name="val-input1"></a>`input1`

```sml
val input1 : instream -> elem option
```

<details><summary>Tests (12)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `characters-then-NONE` &middot; `empty-file` &middot; `NONE-again-at-end-of-stream` &middot; `newline-NUL-and-high-characters` &middot; `removes-one-character` &middot; `NONE-after-input1-and-inputAll` &middot; `then-inputLine` &middot; `every-character` &middot; `large` &middot; `closed-stream` &middot; `file-grows-after-end-of-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `passes-an-end-of-stream`

</details>

### <a name="val-inputn"></a>`inputN`

```sml
val inputN : instream * int -> vector
```

<details><summary>Tests (16)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `pieces-then-empty` &middot; `exactly-the-rest` &middot; `more-than-there-is` &middot; `one` &middot; `zero-reads-nothing` &middot; `empty-after-inputN-and-inputAll` &middot; `empty-file` &middot; `does-not-stop-at-a-newline` &middot; `Size-negative` (raises Size) &middot; `Size-negative-at-end-of-stream` (raises Size) &middot; `negative-reads-nothing` &middot; `more-than-maxSize-of-a-short-file` &middot; `large` &middot; `closed-stream` &middot; `random-mix-of-operations-*` &middot; `random-mix-of-operations-large-*`

</details>

### <a name="val-inputall"></a>`inputAll`

```sml
val inputAll : instream -> vector
```

<details><summary>Tests (14)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `whole-file` &middot; `empty-file` &middot; `again-at-end-of-stream` &middot; `rest-after-inputLine` &middot; `empty-after-inputLine-and-inputAll` &middot; `every-character` &middot; `large` &middot; `no-final-newline-added` &middot; `file-grows-after-end-of-stream` &middot; `empty-after-input1-and-inputAll` &middot; `empty-after-lookahead-and-inputAll` &middot; `empty-after-endOfStream-and-inputAll` &middot; `empty-after-canInput-and-inputAll`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `up-to-each-end-of-stream`

</details>

### <a name="val-caninput"></a>`canInput`

```sml
val canInput : instream * int -> int option
```

<details><summary>Tests (9)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `characters-available` &middot; `one` &middot; `more-than-there-is` &middot; `empty-file` &middot; `at-end-of-stream` &middot; `removes-nothing` &middot; `zero` &middot; `Size-negative` (raises Size) &middot; `closed-stream`

</details>

### <a name="val-lookahead"></a>`lookahead`

```sml
val lookahead : instream -> elem option
```

<details><summary>Tests (9)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `does-not-remove` &middot; `then-inputAll` &middot; `NONE-after-lookahead-and-inputAll` &middot; `then-inputLine` &middot; `empty-file` &middot; `after-each-line` &middot; `newline-and-NUL` &middot; `closed-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `does-not-pass-an-end-of-stream`

</details>

### <a name="val-closein"></a>`closeIn`

```sml
val closeIn : instream -> unit
```

<details><summary>Tests (10)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `twice` &middot; `then-inputAll-is-empty` &middot; `then-inputLine-is-NONE` &middot; `then-inputAll-again` &middot; `unread-characters-are-dropped` &middot; `unread-lines-are-dropped` &middot; `other-streams-stay-open` &middot; `file-can-be-rewritten`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `shared-functional-stream` &middot; `closes-the-reader`

</details>

### <a name="val-endofstream"></a>`endOfStream`

```sml
val endOfStream : instream -> bool
```

<details><summary>Tests (10)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `empty-file` &middot; `characters-available` &middot; `removes-nothing` &middot; `true-after-endOfStream-and-inputAll` &middot; `around-each-line` &middot; `after-inputAll` &middot; `true-then-inputLine-is-NONE` &middot; `closed-stream` &middot; `file-grows-after-end-of-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `more-after-an-end-of-stream`

</details>

### <a name="val-output"></a>`output`

```sml
val output : outstream * vector -> unit
```

<details><summary>Tests (14)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `in-order` &middot; `empty-string` &middot; `every-character` &middot; `no-line-end-translation` &middot; `large` &middot; `large-size` &middot; `Io-closed-stream` (raises) &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name` &middot; `closed-stream-writes-nothing` &middot; `random-chunks-*` &middot; `random-chunks-large`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `shared-stream`

</details>

### <a name="val-output1"></a>`output1`

```sml
val output1 : outstream * elem -> unit
```

<details><summary>Tests (8)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `in-order` &middot; `mixed-with-output` &middot; `every-character` &middot; `Io-closed-stream` (raises) &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name` &middot; `large`

</details>

### <a name="val-flushout"></a>`flushOut`

```sml
val flushOut : outstream -> unit
```

<details><summary>Tests (5)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `makes-output-visible` &middot; `nothing-to-flush` &middot; `twice` &middot; `closed-stream-is-a-no-op`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `flushes-the-stream`

</details>

### <a name="val-closeout"></a>`closeOut`

```sml
val closeOut : outstream -> unit
```

<details><summary>Tests (5)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `flushes` &middot; `twice` &middot; `other-streams-stay-open`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `shared-stream` (raises) &middot; `flushes-and-closes`

</details>

### <a name="val-mkinstream"></a>`mkInstream`

```sml
val mkInstream : StreamIO.instream -> instream
```

<details><summary>Tests (3)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `reads-the-functional-stream` &middot; `from-a-stream-part-read` &middot; `does-not-change-the-functional-stream`

</details>

### <a name="val-getinstream"></a>`getInstream`

```sml
val getInstream : instream -> StreamIO.instream
```

<details><summary>Tests (4)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `current-version` &middot; `fresh` &middot; `input-from-it-is-read-again`

</details>

### <a name="val-setinstream"></a>`setInstream`

```sml
val setInstream : instream * StreamIO.instream -> unit
```

<details><summary>Tests (3)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `redirects` &middot; `after-getInstream-and-input` &middot; `reread`

</details>

### <a name="val-mkoutstream"></a>`mkOutstream`

```sml
val mkOutstream : StreamIO.outstream -> outstream
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `writes-to-the-stream` &middot; `keeps-the-buffer-mode`

</details>

### <a name="val-getoutstream"></a>`getOutstream`

```sml
val getOutstream : outstream -> StreamIO.outstream
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `the-same-stream` &middot; `flushes`

</details>

### <a name="val-setoutstream"></a>`setOutstream`

```sml
val setOutstream : outstream * StreamIO.outstream -> unit
```

<details><summary>Tests (3)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `redirects` &middot; `flushes-the-old-stream` &middot; `save-and-restore`

</details>

### <a name="val-getposout"></a>`getPosOut`

```sml
val getPosOut : outstream -> StreamIO.out_pos
```

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `Io-without-positions` (raises)

</details>

### <a name="val-setposout"></a>`setPosOut`

```sml
val setPosOut : outstream * StreamIO.out_pos -> unit
```

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-overwrites`

</details>

## The members of TEXT\_IO

### <a name="val-inputline"></a>`inputLine`

```sml
val inputLine : instream -> string option
```

<details><summary>Tests (15)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `NONE-after-inputLine-and-inputAll` &middot; `lines-then-NONE` &middot; `final-line-gets-newline` &middot; `one-character-without-newline` &middot; `empty-file` &middot; `NONE-again-at-end-of-stream` &middot; `empty-lines` &middot; `carriage-return-is-kept` &middot; `NUL-and-high-characters` &middot; `long-line-without-newline` &middot; `large` &middot; `after-inputAll` &middot; `file-grows-after-end-of-stream` &middot; `random-lines-*` &middot; `reads-on-after-a-consumed-end-of-stream`

</details>

### <a name="val-outputsubstr"></a>`outputSubstr`

```sml
val outputSubstr : outstream * substring -> unit
```

<details><summary>Tests (9)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `part-of-a-string` &middot; `whole-string` &middot; `empty` &middot; `in-order` &middot; `mixed-with-output` &middot; `large` &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name`

</details>

### <a name="val-openin"></a>`openIn`

```sml
val openIn : string -> instream
```

<details><summary>Tests (7)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `reads-the-file` &middot; `Io-file-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `does-not-create-the-file` &middot; `Io-empty-name` (raises)

</details>

### <a name="val-openout"></a>`openOut`

```sml
val openOut : string -> outstream
```

<details><summary>Tests (9)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `creates-the-file` &middot; `truncates-an-existing-file` &middot; `truncates-at-open` &middot; `nothing-written` &middot; `Io-directory-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `left-open-at-exit`

</details>

### <a name="val-openappend"></a>`openAppend`

```sml
val openAppend : string -> outstream
```

<details><summary>Tests (11)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `creates-the-file` &middot; `appends-to-an-existing-file` &middot; `keeps-the-contents` &middot; `three-times` &middot; `output1` &middot; `Io-directory-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `Io-closed-stream` &middot; `random-pieces`

</details>

### <a name="val-openstring"></a>`openString`

```sml
val openString : string -> instream
```

<details><summary>Tests (12)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `inputAll` &middot; `empty` &middot; `empty-inputLine` &middot; `inputLine` &middot; `streams-are-independent` &middot; `every-character` &middot; `large` &middot; `inputAll-twice` &middot; `closeIn` &middot; `random-lines-*` &middot; `random-mix-of-operations-*` &middot; `random-mix-of-operations-large`

</details>

### <a name="val-stdin"></a>`stdIn`

```sml
val stdIn : instream
```

<details><summary>Tests (5)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `inputLine-at-end-of-stream` &middot; `inputAll-at-end-of-stream` &middot; `input-at-end-of-stream` &middot; `input1-at-end-of-stream` &middot; `endOfStream`

</details>

### <a name="val-stdout"></a>`stdOut`

```sml
val stdOut : outstream
```

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `output-and-flushOut` &middot; `is-the-stream-of-print`

</details>

### <a name="val-stderr"></a>`stdErr`

```sml
val stdErr : outstream
```

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `output-and-flushOut`

</details>

### <a name="val-print"></a>`print`

```sml
val print : string -> unit
```

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `empty-string` &middot; `returns-unit`

</details>

### <a name="val-scanstream"></a>`scanStream`

```sml
val scanStream : ((Char.char, StreamIO.instream) StringCvt.reader
                  -> ('a, StreamIO.instream) StringCvt.reader)
                 -> instream -> 'a option
```

<details><summary>Tests (16)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `number-then-rest` &middot; `stops-before-the-first-other-character` &middot; `negative-number` &middot; `NONE-reads-nothing` &middot; `NONE-keeps-skipped-whitespace` &middot; `NONE-keeps-a-sign` &middot; `empty-file` &middot; `number-up-to-end-of-stream` &middot; `one-after-another` &middot; `then-inputLine` &middot; `own-scanner` &middot; `own-scanner-fails-at-end-of-stream` &middot; `lookahead-is-not-lost` &middot; `scanner-that-reads-nothing` &middot; `closed-stream` &middot; `large`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_text\_io.sml; do not edit.</sub>
