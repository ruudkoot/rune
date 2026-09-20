# signature TEXT_IO

[The Standard ML Basis Library](../README.md) &rsaquo; **TEXT_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 36 entries documented |
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

### <a name="type-elem"></a>`elem`

```sml
type elem = StreamIO.elem
```

### <a name="type-instream"></a>`instream`

```sml
type instream
```

### <a name="type-outstream"></a>`outstream`

```sml
type outstream
```

### <a name="val-input"></a>`input`

```sml
val input : instream -> vector
```

### <a name="val-input1"></a>`input1`

```sml
val input1 : instream -> elem option
```

### <a name="val-inputn"></a>`inputN`

```sml
val inputN : instream * int -> vector
```

### <a name="val-inputall"></a>`inputAll`

```sml
val inputAll : instream -> vector
```

### <a name="val-caninput"></a>`canInput`

```sml
val canInput : instream * int -> int option
```

### <a name="val-lookahead"></a>`lookahead`

```sml
val lookahead : instream -> elem option
```

### <a name="val-closein"></a>`closeIn`

```sml
val closeIn : instream -> unit
```

### <a name="val-endofstream"></a>`endOfStream`

```sml
val endOfStream : instream -> bool
```

### <a name="val-output"></a>`output`

```sml
val output : outstream * vector -> unit
```

### <a name="val-output1"></a>`output1`

```sml
val output1 : outstream * elem -> unit
```

### <a name="val-flushout"></a>`flushOut`

```sml
val flushOut : outstream -> unit
```

### <a name="val-closeout"></a>`closeOut`

```sml
val closeOut : outstream -> unit
```

### <a name="val-mkinstream"></a>`mkInstream`

```sml
val mkInstream : StreamIO.instream -> instream
```

### <a name="val-getinstream"></a>`getInstream`

```sml
val getInstream : instream -> StreamIO.instream
```

### <a name="val-setinstream"></a>`setInstream`

```sml
val setInstream : instream * StreamIO.instream -> unit
```

### <a name="val-mkoutstream"></a>`mkOutstream`

```sml
val mkOutstream : StreamIO.outstream -> outstream
```

### <a name="val-getoutstream"></a>`getOutstream`

```sml
val getOutstream : outstream -> StreamIO.outstream
```

### <a name="val-setoutstream"></a>`setOutstream`

```sml
val setOutstream : outstream * StreamIO.outstream -> unit
```

### <a name="val-getposout"></a>`getPosOut`

```sml
val getPosOut : outstream -> StreamIO.out_pos
```

### <a name="val-setposout"></a>`setPosOut`

```sml
val setPosOut : outstream * StreamIO.out_pos -> unit
```

## The members of TEXT\_IO

### <a name="val-inputline"></a>`inputLine`

```sml
val inputLine : instream -> string option
```

### <a name="val-outputsubstr"></a>`outputSubstr`

```sml
val outputSubstr : outstream * substring -> unit
```

### <a name="val-openin"></a>`openIn`

```sml
val openIn : string -> instream
```

### <a name="val-openout"></a>`openOut`

```sml
val openOut : string -> outstream
```

### <a name="val-openappend"></a>`openAppend`

```sml
val openAppend : string -> outstream
```

### <a name="val-openstring"></a>`openString`

```sml
val openString : string -> instream
```

### <a name="val-stdin"></a>`stdIn`

```sml
val stdIn : instream
```

### <a name="val-stdout"></a>`stdOut`

```sml
val stdOut : outstream
```

### <a name="val-stderr"></a>`stdErr`

```sml
val stdErr : outstream
```

### <a name="val-print"></a>`print`

```sml
val print : string -> unit
```

### <a name="val-scanstream"></a>`scanStream`

```sml
val scanStream : ((Char.char, StreamIO.instream) StringCvt.reader
                  -> ('a, StreamIO.instream) StringCvt.reader)
                 -> instream -> 'a option
```

---

<sub>Generated by runedoc from lib/basis/sig\_text\_io.sml; do not edit.</sub>
