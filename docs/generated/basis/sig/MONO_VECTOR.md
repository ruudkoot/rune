# signature MONO_VECTOR

[The Standard ML Basis Library](../README.md) &rsaquo; **MONO_VECTOR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 19 |
| Documentation | 0 of 22 entries documented |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_VECTOR
structure BoolVector : MONO_VECTOR where type elem = bool  (* optional *)
structure CharVector : MONO_VECTOR where type vector = String.string where type elem = char
structure Int16Vector : MONO_VECTOR where type elem = Int16.int  (* optional *)
structure Int32Vector : MONO_VECTOR where type elem = Int32.int  (* optional *)
structure Int64Vector : MONO_VECTOR where type elem = Int64.int  (* optional *)
structure Int8Vector : MONO_VECTOR where type elem = Int8.int  (* optional *)
structure IntVector : MONO_VECTOR where type elem = int  (* optional *)
structure LargeIntVector : MONO_VECTOR where type elem = LargeInt.int  (* optional *)
structure LargeRealVector : MONO_VECTOR where type elem = LargeReal.real  (* optional *)
structure LargeWordVector : MONO_VECTOR where type elem = LargeWord.word  (* optional *)
structure Real32Vector : MONO_VECTOR where type elem = Real32.real  (* optional *)
structure Real64Vector : MONO_VECTOR where type elem = Real64.real  (* optional *)
structure RealVector : MONO_VECTOR where type elem = real  (* optional *)
structure WideCharVector :> MONO_VECTOR where type elem = WideChar.char  (* optional *)
structure Word16Vector : MONO_VECTOR where type elem = Word16.word  (* optional *)
structure Word32Vector : MONO_VECTOR where type elem = Word32.word  (* optional *)
structure Word64Vector : MONO_VECTOR where type elem = Word64.word  (* optional *)
structure Word8Vector : MONO_VECTOR where type elem = Word8.word
structure WordVector : MONO_VECTOR where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BoolVector` | The monomorphic vectors and arrays of booleans and their slices, and the two-dimensional arrays (all optional in the specification), in one file: a program that names one of them loads the five. The vector is a polymorphic vector (RuneMonoVectorFn), the array a polymorphic array. | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| `CharVector` | CharVector: CharVector.vector is string. | [lib/basis/charvector.sml](../../../../lib/basis/charvector.sml) |
| `Int16Vector` | The monomorphic vectors and arrays of Int16.int, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| `Int32Vector` | The monomorphic vectors and arrays of Int32.int, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| `Int64Vector` | Int64 is Int, so its vectors, arrays, slices and two-dimensional arrays (optional in the specification) are those of Int. | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| `Int8Vector` | The monomorphic vectors and arrays of Int8.int, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| `IntVector` | The monomorphic vectors and arrays of int, their slices and the two-dimensional arrays (optional in the specification). Int64Vector and the rest of that family are these (mono\_int64.sml). | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| `LargeIntVector` | The monomorphic vectors and arrays of LargeInt.int (IntInf.int), their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| `LargeRealVector` | LargeReal is Real, so its vectors, arrays, slices and two-dimensional arrays (optional in the specification) are those of Real. | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| `LargeWordVector` | LargeWord is Word, so its vectors, arrays, slices and two-dimensional arrays (optional in the specification) are those of Word. | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| `Real32Vector` | The monomorphic vectors and arrays of Real32.real, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| `Real64Vector` | Real64 is Real, so its vectors, arrays, slices and two-dimensional arrays (optional in the specification) are those of Real. | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| `RealVector` | The monomorphic vectors and arrays of real, their slices and the two-dimensional arrays (optional in the specification). The elements do not admit equality, which MONO\_VECTOR and MONO\_ARRAY do not ask of them. LargeRealVector, Real64Vector and the rest of those families are these (mono\_largereal.sml, mono\_real64.sml). | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| `WideCharVector` | Sealed with a vector of its own (MONO\_VECTOR\_EQ), so that WideString.string is a type name: the constants of a type are overloaded at a name. | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |
| `Word16Vector` | The monomorphic vectors and arrays of Word16.word, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| `Word32Vector` | The monomorphic vectors and arrays of Word32.word, their slices and the two-dimensional arrays (optional in the specification). | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| `Word64Vector` | Word64 is Word, so its vectors, arrays, slices and two-dimensional arrays (optional in the specification) are those of Word. | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| `Word8Vector` | Word8Vector: a vector of bytes is a string. | [lib/basis/word8vector.sml](../../../../lib/basis/word8vector.sml) |
| `WordVector` | The monomorphic vectors and arrays of word, their slices and the two-dimensional arrays (optional in the specification). LargeWordVector, Word64Vector and the rest of those families are these (mono\_largeword.sml, mono\_word64.sml). | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

The signatures of the monomorphic vectors, arrays and their slices.

## Interface

<pre>
signature MONO_VECTOR =
sig
  type <a href="#type-vector">vector</a>
  type <a href="#type-elem">elem</a>
  val <a href="#val-maxlen">maxLen</a> : int
  val <a href="#val-fromlist">fromList</a> : elem list -&gt; vector
  val <a href="#val-tabulate">tabulate</a> : int * (int -&gt; elem) -&gt; vector
  val <a href="#val-length">length</a> : vector -&gt; int
  val <a href="#val-sub">sub</a> : vector * int -&gt; elem
  val <a href="#val-update">update</a> : vector * int * elem -&gt; vector
  val <a href="#val-concat">concat</a> : vector list -&gt; vector
  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; vector -&gt; unit
  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; vector -&gt; unit
  val <a href="#val-mapi">mapi</a> : (int * elem -&gt; elem) -&gt; vector -&gt; vector
  val <a href="#val-map">map</a> : (elem -&gt; elem) -&gt; vector -&gt; vector
  val <a href="#val-foldli">foldli</a> : (int * elem * 'a -&gt; 'a) -&gt; 'a -&gt; vector -&gt; 'a
  val <a href="#val-foldri">foldri</a> : (int * elem * 'a -&gt; 'a) -&gt; 'a -&gt; vector -&gt; 'a
  val <a href="#val-foldl">foldl</a> : (elem * 'a -&gt; 'a) -&gt; 'a -&gt; vector -&gt; 'a
  val <a href="#val-foldr">foldr</a> : (elem * 'a -&gt; 'a) -&gt; 'a -&gt; vector -&gt; 'a
  val <a href="#val-findi">findi</a> : (int * elem -&gt; bool) -&gt; vector -&gt; (int * elem) option
  val <a href="#val-find">find</a> : (elem -&gt; bool) -&gt; vector -&gt; elem option
  val <a href="#val-exists">exists</a> : (elem -&gt; bool) -&gt; vector -&gt; bool
  val <a href="#val-all">all</a> : (elem -&gt; bool) -&gt; vector -&gt; bool
  val <a href="#val-collate">collate</a> : (elem * elem -&gt; order) -&gt; vector * vector -&gt; order
end
</pre>

### <a name="type-vector"></a>`vector`

```sml
type vector
```

### <a name="type-elem"></a>`elem`

```sml
type elem
```

### <a name="val-maxlen"></a>`maxLen`

```sml
val maxLen : int
```

### <a name="val-fromlist"></a>`fromList`

```sml
val fromList : elem list -> vector
```

### <a name="val-tabulate"></a>`tabulate`

```sml
val tabulate : int * (int -> elem) -> vector
```

### <a name="val-length"></a>`length`

```sml
val length : vector -> int
```

### <a name="val-sub"></a>`sub`

```sml
val sub : vector * int -> elem
```

### <a name="val-update"></a>`update`

```sml
val update : vector * int * elem -> vector
```

### <a name="val-concat"></a>`concat`

```sml
val concat : vector list -> vector
```

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> vector -> unit
```

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> vector -> unit
```

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * elem -> elem) -> vector -> vector
```

### <a name="val-map"></a>`map`

```sml
val map : (elem -> elem) -> vector -> vector
```

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'a -> 'a) -> 'a -> vector -> 'a
```

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'a -> 'a) -> 'a -> vector -> 'a
```

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'a -> 'a) -> 'a -> vector -> 'a
```

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'a -> 'a) -> 'a -> vector -> 'a
```

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> vector -> (int * elem) option
```

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> vector -> elem option
```

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> vector -> bool
```

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> vector -> bool
```

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> vector * vector -> order
```

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>
