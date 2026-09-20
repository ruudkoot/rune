# signature MONO_ARRAY2

[The Standard ML Basis Library](../README.md) &rsaquo; **MONO_ARRAY2**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 18 |
| Documentation | 0 of 22 entries documented |
| Source | [lib/basis/sig\_mono\_array2.sml](../../../../lib/basis/sig_mono_array2.sml) |

## Synopsis

```sml
signature MONO_ARRAY2
structure BoolArray2 : MONO_ARRAY2 where type vector = BoolVector.vector where type elem = bool  (* optional *)
structure CharArray2 : MONO_ARRAY2 where type vector = CharVector.vector where type elem = char  (* optional *)
structure Int16Array2 : MONO_ARRAY2 where type vector = Int16Vector.vector where type elem = Int16.int  (* optional *)
structure Int32Array2 : MONO_ARRAY2 where type vector = Int32Vector.vector where type elem = Int32.int  (* optional *)
structure Int64Array2 : MONO_ARRAY2 where type vector = Int64Vector.vector where type elem = Int64.int  (* optional *)
structure Int8Array2 : MONO_ARRAY2 where type vector = Int8Vector.vector where type elem = Int8.int  (* optional *)
structure IntArray2 : MONO_ARRAY2 where type vector = IntVector.vector where type elem = int  (* optional *)
structure LargeIntArray2 : MONO_ARRAY2 where type vector = LargeIntVector.vector where type elem = LargeInt.int  (* optional *)
structure LargeRealArray2 : MONO_ARRAY2 where type vector = LargeRealVector.vector where type elem = LargeReal.real  (* optional *)
structure LargeWordArray2 : MONO_ARRAY2 where type vector = LargeWordVector.vector where type elem = LargeWord.word  (* optional *)
structure Real32Array2 : MONO_ARRAY2 where type vector = Real32Vector.vector where type elem = Real32.real  (* optional *)
structure Real64Array2 : MONO_ARRAY2 where type vector = Real64Vector.vector where type elem = Real64.real  (* optional *)
structure RealArray2 : MONO_ARRAY2 where type vector = RealVector.vector where type elem = real  (* optional *)
structure Word16Array2 : MONO_ARRAY2 where type vector = Word16Vector.vector where type elem = Word16.word  (* optional *)
structure Word32Array2 : MONO_ARRAY2 where type vector = Word32Vector.vector where type elem = Word32.word  (* optional *)
structure Word64Array2 : MONO_ARRAY2 where type vector = Word64Vector.vector where type elem = Word64.word  (* optional *)
structure Word8Array2 : MONO_ARRAY2 where type vector = Word8Vector.vector where type elem = Word8.word  (* optional *)
structure WordArray2 : MONO_ARRAY2 where type vector = WordVector.vector where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BoolArray2` |  | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| `CharArray2` | CharArray2: two-dimensional arrays of characters (optional in the specification), whose rows and columns are strings. | [lib/basis/chararray2.sml](../../../../lib/basis/chararray2.sml) |
| `Int16Array2` |  | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| `Int32Array2` |  | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| `Int64Array2` |  | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| `Int8Array2` |  | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| `IntArray2` |  | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| `LargeIntArray2` |  | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| `LargeRealArray2` |  | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| `LargeWordArray2` |  | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| `Real32Array2` |  | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| `Real64Array2` |  | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| `RealArray2` |  | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| `Word16Array2` |  | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| `Word32Array2` |  | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| `Word64Array2` |  | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| `Word8Array2` | Word8Array2: two-dimensional arrays of bytes (optional in the specification), whose rows and columns are Word8Vector.vector values. | [lib/basis/word8array2.sml](../../../../lib/basis/word8array2.sml) |
| `WordArray2` |  | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

signature MONO\_ARRAY2, transcribed from
<https://smlfamily.github.io/Basis/mono-array2.html>

The constraints of the instances (`structure Word8Array2 :> MONO_ARRAY2 where type vector = Word8Vector.vector where type elem = Word8.word`, the
same for CharArray2 with CharVector.vector and char, and for BoolArray2,
IntArray2, WordArray2, RealArray2, LargeIntArray2, LargeWordArray2,
LargeRealArray2, Int\<N\>Array2, Word\<N\>Array2 and Real\<N\>Array2 with the
vector of their element type) are in tests/basis/word8array2\_sig.sml,
tests/basis/chararray2\_sig.sml and tests/basis/mono.\*\_sig.sml. "If an
implementation provides any structure matching MONO\_ARRAY2, it must also
supply the structure Array2 and its signature ARRAY2": the traversal is
that of Array2.

## Interface

<pre>
signature MONO_ARRAY2 =
sig
  eqtype <a href="#type-array">array</a>
  type <a href="#type-elem">elem</a>
  type <a href="#type-vector">vector</a>
  type <a href="#type-region">region</a> = {<a href="#fld-region.base">base</a> : array, <a href="#fld-region.row">row</a> : int, <a href="#fld-region.col">col</a> : int, <a href="#fld-region.nrows">nrows</a> : int option, <a href="#fld-region.ncols">ncols</a> : int option}
  datatype <a href="#type-traversal">traversal</a> = datatype Array2.traversal

  val <a href="#val-array">array</a> : int * int * elem -&gt; array
  val <a href="#val-fromlist">fromList</a> : elem list list -&gt; array
  val <a href="#val-tabulate">tabulate</a> : traversal -&gt; int * int * (int * int -&gt; elem) -&gt; array
  val <a href="#val-sub">sub</a> : array * int * int -&gt; elem
  val <a href="#val-update">update</a> : array * int * int * elem -&gt; unit
  val <a href="#val-dimensions">dimensions</a> : array -&gt; int * int
  val <a href="#val-ncols">nCols</a> : array -&gt; int
  val <a href="#val-nrows">nRows</a> : array -&gt; int
  val <a href="#val-row">row</a> : array * int -&gt; vector
  val <a href="#val-column">column</a> : array * int -&gt; vector
  val <a href="#val-copy">copy</a> : {<a href="#fld-copy.src">src</a> : region, <a href="#fld-copy.dst">dst</a> : array, <a href="#fld-copy.dst_row">dst_row</a> : int, <a href="#fld-copy.dst_col">dst_col</a> : int} -&gt; unit
  val <a href="#val-appi">appi</a> : traversal -&gt; (int * int * elem -&gt; unit) -&gt; region -&gt; unit
  val <a href="#val-app">app</a> : traversal -&gt; (elem -&gt; unit) -&gt; array -&gt; unit
  val <a href="#val-foldi">foldi</a> : traversal -&gt; (int * int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; region -&gt; 'b
  val <a href="#val-fold">fold</a> : traversal -&gt; (elem * 'b -&gt; 'b) -&gt; 'b -&gt; array -&gt; 'b
  val <a href="#val-modifyi">modifyi</a> : traversal -&gt; (int * int * elem -&gt; elem) -&gt; region -&gt; unit
  val <a href="#val-modify">modify</a> : traversal -&gt; (elem -&gt; elem) -&gt; array -&gt; unit
end
</pre>

### <a name="type-array"></a>`array`

```sml
eqtype array
```

### <a name="type-elem"></a>`elem`

```sml
type elem
```

### <a name="type-vector"></a>`vector`

```sml
type vector
```

### <a name="type-region"></a>`region`

```sml
type region = {base : array, row : int, col : int, nrows : int option, ncols : int option}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-region.base"></a>`base` | `array` |  |
| <a name="fld-region.row"></a>`row` | `int` |  |
| <a name="fld-region.col"></a>`col` | `int` |  |
| <a name="fld-region.nrows"></a>`nrows` | `int option` |  |
| <a name="fld-region.ncols"></a>`ncols` | `int option` |  |

### <a name="type-traversal"></a>`traversal`

```sml
datatype traversal = datatype Array2.traversal
```

### <a name="val-array"></a>`array`

```sml
val array : int * int * elem -> array
```

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : elem list list -> array
```

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : traversal -> int * int * (int * int -> elem) -> array
```

### <a name="val-sub"></a>`sub`

```sml
val sub : array * int * int -> elem
```

### <a name="val-update"></a>`update`

```sml
val update : array * int * int * elem -> unit
```

### <a name="val-dimensions"></a>`dimensions`

```sml
val dimensions : array -> int * int
```

### <a name="val-ncols"></a>`nCols`

```sml
val nCols : array -> int
```

### <a name="val-nrows"></a>`nRows`

```sml
val nRows : array -> int
```

### <a name="val-row"></a>`row`

```sml
val row : array * int -> vector
```

### <a name="val-column"></a>`column`

```sml
val column : array * int -> vector
```

### <a name="val-copy"></a>`copy`

```sml
val copy : {src : region, dst : array, dst_row : int, dst_col : int} -> unit
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-copy.src"></a>`src` | `region` |  |
| <a name="fld-copy.dst"></a>`dst` | `array` |  |
| <a name="fld-copy.dst_row"></a>`dst_row` | `int` |  |
| <a name="fld-copy.dst_col"></a>`dst_col` | `int` |  |

### <a name="val-appi"></a>`appi`

```sml
val appi : traversal -> (int * int * elem -> unit) -> region -> unit
```

### <a name="val-app"></a>`app`

```sml
val app : traversal -> (elem -> unit) -> array -> unit
```

### <a name="val-foldi"></a>`foldi`

```sml
val foldi : traversal -> (int * int * elem * 'b -> 'b) -> 'b -> region -> 'b
```

### <a name="val-fold"></a>`fold`

```sml
val fold : traversal -> (elem * 'b -> 'b) -> 'b -> array -> 'b
```

### <a name="val-modifyi"></a>`modifyi`

```sml
val modifyi : traversal -> (int * int * elem -> elem) -> region -> unit
```

### <a name="val-modify"></a>`modify`

```sml
val modify : traversal -> (elem -> elem) -> array -> unit
```

---

<sub>Generated by runedoc from lib/basis/sig\_mono\_array2.sml; do not edit.</sub>
