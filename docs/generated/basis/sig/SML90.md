# signature SML90

[The Standard ML Basis Library](../README.md) &rsaquo; **SML90**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 36 entries documented |
| Source | [lib/basis/sig\_sml90.sml](../../../../lib/basis/sig_sml90.sml) |

## Synopsis

```sml
signature SML90
structure SML90 : SML90  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `SML90` | SML90: the initial basis of the 1990 Definition, over Real.Math, String and TextIO. As in MLton's (unexposed) SML90, which Poly/ML agrees with: the arithmetic exceptions are Overflow and Mod is Div, which the Library raises in their place; Sqrt, Ln, Ord, Io and Interrupt are new, and sqrt, ln, ord and the functions on streams raise them. | [lib/basis/sml90.sml](../../../../lib/basis/sml90.sml) |

signature SML90. The page of the specification that defined it
(sml90.html) is no longer at <https://smlfamily.github.io/Basis/>; transcribed
from the signature of MLton's basis library, which follows it, in the
order of the page.

## Interface

<pre>
signature SML90 =
sig
  type <a href="#type-instream">instream</a>
  type <a href="#type-outstream">outstream</a>
  exception <a href="#exn-abs">Abs</a>
  exception <a href="#exn-quot">Quot</a>
  exception <a href="#exn-prod">Prod</a>
  exception <a href="#exn-neg">Neg</a>
  exception <a href="#exn-sum">Sum</a>
  exception <a href="#exn-diff">Diff</a>
  exception <a href="#exn-floor">Floor</a>
  exception <a href="#exn-exp">Exp</a>
  exception <a href="#exn-sqrt">Sqrt</a>
  exception <a href="#exn-ln">Ln</a>
  exception <a href="#exn-ord">Ord</a>
  exception <a href="#exn-mod">Mod</a>
  exception <a href="#exn-io">Io</a> of string
  exception <a href="#exn-interrupt">Interrupt</a>
  val <a href="#val-sqrt">sqrt</a> : real -&gt; real
  val <a href="#val-exp">exp</a> : real -&gt; real
  val <a href="#val-ln">ln</a> : real -&gt; real
  val <a href="#val-sin">sin</a> : real -&gt; real
  val <a href="#val-cos">cos</a> : real -&gt; real
  val <a href="#val-arctan">arctan</a> : real -&gt; real
  val <a href="#val-ord">ord</a> : string -&gt; int
  val <a href="#val-chr">chr</a> : int -&gt; string
  val <a href="#val-explode">explode</a> : string -&gt; string list
  val <a href="#val-implode">implode</a> : string list -&gt; string
  val <a href="#val-lookahead">lookahead</a> : instream -&gt; string
  val <a href="#val-std_in">std_in</a> : instream
  val <a href="#val-std_out">std_out</a> : outstream
  val <a href="#val-open_in">open_in</a> : string -&gt; instream
  val <a href="#val-open_out">open_out</a> : string -&gt; outstream
  val <a href="#val-close_in">close_in</a> : instream -&gt; unit
  val <a href="#val-close_out">close_out</a> : outstream -&gt; unit
  val <a href="#val-input">input</a> : instream * int -&gt; string
  val <a href="#val-output">output</a> : outstream * string -&gt; unit
  val <a href="#val-end_of_stream">end_of_stream</a> : instream -&gt; bool
end
</pre>

### <a name="type-instream"></a>`instream`

```sml
type instream
```

### <a name="type-outstream"></a>`outstream`

```sml
type outstream
```

### <a name="exn-abs"></a>`Abs`

```sml
exception Abs
```

### <a name="exn-quot"></a>`Quot`

```sml
exception Quot
```

### <a name="exn-prod"></a>`Prod`

```sml
exception Prod
```

### <a name="exn-neg"></a>`Neg`

```sml
exception Neg
```

### <a name="exn-sum"></a>`Sum`

```sml
exception Sum
```

### <a name="exn-diff"></a>`Diff`

```sml
exception Diff
```

### <a name="exn-floor"></a>`Floor`

```sml
exception Floor
```

### <a name="exn-exp"></a>`Exp`

```sml
exception Exp
```

### <a name="exn-sqrt"></a>`Sqrt`

```sml
exception Sqrt
```

### <a name="exn-ln"></a>`Ln`

```sml
exception Ln
```

### <a name="exn-ord"></a>`Ord`

```sml
exception Ord
```

### <a name="exn-mod"></a>`Mod`

```sml
exception Mod
```

### <a name="exn-io"></a>`Io`

```sml
exception Io of string
```

### <a name="exn-interrupt"></a>`Interrupt`

```sml
exception Interrupt
```

### <a name="val-sqrt"></a>`sqrt`

```sml
val sqrt : real -> real
```

### <a name="val-exp"></a>`exp`

```sml
val exp : real -> real
```

### <a name="val-ln"></a>`ln`

```sml
val ln : real -> real
```

### <a name="val-sin"></a>`sin`

```sml
val sin : real -> real
```

### <a name="val-cos"></a>`cos`

```sml
val cos : real -> real
```

### <a name="val-arctan"></a>`arctan`

```sml
val arctan : real -> real
```

### <a name="val-ord"></a>`ord`

```sml
val ord : string -> int
```

### <a name="val-chr"></a>`chr`

```sml
val chr : int -> string
```

### <a name="val-explode"></a>`explode`

```sml
val explode : string -> string list
```

### <a name="val-implode"></a>`implode`

```sml
val implode : string list -> string
```

### <a name="val-lookahead"></a>`lookahead`

```sml
val lookahead : instream -> string
```

### <a name="val-std_in"></a>`std_in`

```sml
val std_in : instream
```

### <a name="val-std_out"></a>`std_out`

```sml
val std_out : outstream
```

### <a name="val-open_in"></a>`open_in`

```sml
val open_in : string -> instream
```

### <a name="val-open_out"></a>`open_out`

```sml
val open_out : string -> outstream
```

### <a name="val-close_in"></a>`close_in`

```sml
val close_in : instream -> unit
```

### <a name="val-close_out"></a>`close_out`

```sml
val close_out : outstream -> unit
```

### <a name="val-input"></a>`input`

```sml
val input : instream * int -> string
```

### <a name="val-output"></a>`output`

```sml
val output : outstream * string -> unit
```

### <a name="val-end_of_stream"></a>`end_of_stream`

```sml
val end_of_stream : instream -> bool
```

---

<sub>Generated by runedoc from lib/basis/sig\_sml90.sml; do not edit.</sub>
