# signature ARB_OF

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; **ARB_OF**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 49 |
| Documentation | 2 of 2 entries documented |
| Tests | not listed |
| Source | [lib/test/property/family\_sig.sml](../../../../../lib/test/property/family_sig.sml) |

## Synopsis

```sml
signature ARB_OF
structure CharArb : ARB_OF where type t = Char.char
functor CharArbFn (...) : ARB_OF where type t = C.char
structure CharArray2Arb : ARB_OF where type t = CharArray2.array
structure CharArrayArb : ARB_OF where type t = CharArray.array
structure CharArraySliceArb : ARB_OF where type t = CharArraySlice.slice
structure CharVectorArb : ARB_OF where type t = CharVector.vector
structure CharVectorSliceArb : ARB_OF where type t = CharVectorSlice.slice
structure FixedIntArb : ARB_OF where type t = FixedInt.int
structure Int16Arb : ARB_OF where type t = Int16.int
structure Int32Arb : ARB_OF where type t = Int32.int
structure Int64Arb : ARB_OF where type t = Int64.int
structure Int8Arb : ARB_OF where type t = Int8.int
structure IntArb : ARB_OF where type t = Int.int
structure IntArray2Arb : ARB_OF where type t = IntArray2.array
structure IntInfArb : ARB_OF where type t = IntInf.int
functor IntegerArbFn (...) : ARB_OF where type t = I.int
structure LargeIntArb : ARB_OF where type t = LargeInt.int
structure LargeRealArb : ARB_OF where type t = LargeReal.real
structure LargeWordArb : ARB_OF where type t = LargeWord.word
functor MonoArray2ArbFn (...) : ARB_OF where type t = A.array
functor MonoArrayArbFn (...) : ARB_OF where type t = A.array
functor MonoArraySliceArbFn (...) : ARB_OF where type t = S.slice
functor MonoVectorArbFn (...) : ARB_OF where type t = V.vector
functor MonoVectorSliceArbFn (...) : ARB_OF where type t = S.slice
structure PositionArb : ARB_OF where type t = Position.int
structure Real32Arb : ARB_OF where type t = Real32.real
structure Real64Arb : ARB_OF where type t = Real64.real
structure RealArb : ARB_OF where type t = Real.real
functor RealArbFn (...) : ARB_OF where type t = R.real
structure StringArb : ARB_OF where type t = String.string
functor StringArbFn (...) : ARB_OF where type t = S.string
structure SubstringArb : ARB_OF where type t = Substring.substring
functor SubstringArbFn (...) : ARB_OF where type t = S.substring
structure SysWordArb : ARB_OF where type t = SysWord.word
structure TimeArb : ARB_OF where type t = Time.time
structure WideCharArb : ARB_OF where type t = WideChar.char
structure WideStringArb : ARB_OF where type t = WideString.string
structure WideSubstringArb : ARB_OF where type t = WideSubstring.substring
structure Word16Arb : ARB_OF where type t = Word16.word
structure Word32Arb : ARB_OF where type t = Word32.word
structure Word64Arb : ARB_OF where type t = Word64.word
structure Word8Arb : ARB_OF where type t = Word8.word
structure Word8Array2Arb : ARB_OF where type t = Word8Array2.array
structure Word8ArrayArb : ARB_OF where type t = Word8Array.array
structure Word8ArraySliceArb : ARB_OF where type t = Word8ArraySlice.slice
structure Word8VectorArb : ARB_OF where type t = Word8Vector.vector
structure Word8VectorSliceArb : ARB_OF where type t = Word8VectorSlice.slice
structure WordArb : ARB_OF where type t = Word.word
functor WordArbFn (...) : ARB_OF where type t = W.word
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CharArb`](../str/CharArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| `CharArbFn` | The arbitrary of the characters of a structure of `CHAR`, by the generator principle P5, as [`Gen.code`](../sig/GEN.md#val-code) draws their codes. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`CharArray2Arb`](../str/CharArray2Arb.md) |  | [lib/test/property/arrays2.sml](../../../../../lib/test/property/arrays2.sml) |
| [`CharArrayArb`](../str/CharArrayArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| [`CharArraySliceArb`](../str/CharArraySliceArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| [`CharVectorArb`](../str/CharVectorArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| [`CharVectorSliceArb`](../str/CharVectorSliceArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| [`FixedIntArb`](../str/FixedIntArb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int16Arb`](../str/Int16Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int32Arb`](../str/Int32Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int64Arb`](../str/Int64Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int8Arb`](../str/Int8Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`IntArb`](../str/IntArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`IntArray2Arb`](../str/IntArray2Arb.md) |  | [lib/test/property/arrays2.sml](../../../../../lib/test/property/arrays2.sml) |
| [`IntInfArb`](../str/IntInfArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| `IntegerArbFn` | The arbitrary of the integers of a structure of `INTEGER`, by the generator principles P1 and P2: small, on an edge, or anywhere in the range, a third each; an `IntInf` without bounds by [`Gen.intInf`](../sig/GEN.md#val-intinf). | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`LargeIntArb`](../str/LargeIntArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`LargeRealArb`](../str/LargeRealArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`LargeWordArb`](../str/LargeWordArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| `MonoArray2ArbFn` | The arbitrary of the two-dimensional arrays of a structure of `MONO_ARRAY2`, as [`Arb.array2`](../sig/ARB.md#val-array2) draws them. `name` is the structure's name. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| `MonoArrayArbFn` | The arbitrary of the arrays of a structure of `MONO_ARRAY`, as [`MonoVectorArbFn`](../fun/MonoVectorArbFn.md) draws vectors: a fresh array at every draw, compared by its elements. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| `MonoArraySliceArbFn` | The arbitrary of the slices of a structure of `MONO_ARRAY_SLICE`, as [`MonoVectorSliceArbFn`](../fun/MonoVectorSliceArbFn.md) draws them, over a fresh array of `array` at every draw. `name` is the structure's name. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| `MonoVectorArbFn` | The arbitrary of the vectors of a structure of `MONO_VECTOR`: lists of `elem`, by the generator principle P6. `name` is the structure's name, which the printer writes. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| `MonoVectorSliceArbFn` | The arbitrary of the slices of a structure of `MONO_VECTOR_SLICE`: a vector of `vector`, and a start and a length within it, compared as [`Arb.vectorSlice`](../sig/ARB.md#val-vectorslice) compares slices. `name` is the structure's name. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`PositionArb`](../str/PositionArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`Real32Arb`](../str/Real32Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Real64Arb`](../str/Real64Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`RealArb`](../str/RealArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| `RealArbFn` | The arbitrary of the reals of a structure of `REAL`, by the generator principle P4: a special one, a small one, or any bit pattern, a third each. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`StringArb`](../str/StringArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| `StringArbFn` | The arbitrary of the strings of a structure of `STRING`: lists of the characters of `char`, by the generator principle P6. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`SubstringArb`](../str/SubstringArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| `SubstringArbFn` | The arbitrary of the substrings of a structure of `SUBSTRING`: a string of `string`, and a start and a length within it. `name` is the structure's name, which the printer writes. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`SysWordArb`](../str/SysWordArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`TimeArb`](../str/TimeArb.md) | The arbitrary of `Time.time`: `Time.fromNanoseconds` of a number of nanoseconds drawn by the generator principle P1 over the range that the implementation's times hold, which the specification leaves to it and which is found by doubling a time until `Time` is raised (P12); by P2 where no such range is found below 2^200. | [lib/test/property/data.sml](../../../../../lib/test/property/data.sml) |
| [`WideCharArb`](../str/WideCharArb.md) |  | [lib/test/property/wide.sml](../../../../../lib/test/property/wide.sml) |
| [`WideStringArb`](../str/WideStringArb.md) |  | [lib/test/property/wide.sml](../../../../../lib/test/property/wide.sml) |
| [`WideSubstringArb`](../str/WideSubstringArb.md) |  | [lib/test/property/wide.sml](../../../../../lib/test/property/wide.sml) |
| [`Word16Arb`](../str/Word16Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Word32Arb`](../str/Word32Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Word64Arb`](../str/Word64Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Word8Arb`](../str/Word8Arb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`Word8Array2Arb`](../str/Word8Array2Arb.md) |  | [lib/test/property/arrays2.sml](../../../../../lib/test/property/arrays2.sml) |
| [`Word8ArrayArb`](../str/Word8ArrayArb.md) |  | [lib/test/property/bytes.sml](../../../../../lib/test/property/bytes.sml) |
| [`Word8ArraySliceArb`](../str/Word8ArraySliceArb.md) |  | [lib/test/property/bytes.sml](../../../../../lib/test/property/bytes.sml) |
| [`Word8VectorArb`](../str/Word8VectorArb.md) |  | [lib/test/property/bytes.sml](../../../../../lib/test/property/bytes.sml) |
| [`Word8VectorSliceArb`](../str/Word8VectorSliceArb.md) |  | [lib/test/property/bytes.sml](../../../../../lib/test/property/bytes.sml) |
| [`WordArb`](../str/WordArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| `WordArbFn` | The arbitrary of the words of a structure of `WORD`, by the generator principle P3: small, on an edge (0, 1, the largest, powers of two and their neighbours), or anywhere, a third each. The words are at most 64 bits. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |

The arbitrary of one type of a structure: what the functors of the
library make of a structure of the Basis Library, and what the structures
[`Int8Arb`](../str/Int8Arb.md), [`Word8Arb`](../str/Word8Arb.md), [`CharArraySliceArb`](../str/CharArraySliceArb.md) and the rest are.

The instance of the type of a structure of the Basis Library is the [`arb`](#val-arb)
of the structure of the same name with Arb after it: [`Int8Arb.arb`](#val-arb) for
[`Int8.int`](../../../basis/sig/INTEGER.md#type-int) (docs/plans/quickcheck.md, D4 and M6).

## Interface

<pre>
signature ARB_OF =
sig
  type <a href="#type-t">t</a>
  val <a href="#val-arb">arb</a> : t Arb.arb
end
</pre>

### <a name="type-t"></a>`t`

```sml
type t
```

The type.

### <a name="val-arb"></a>`arb`

```sml
val arb : t Arb.arb
```

The arbitrary of [`t`](#type-t).

---

<sub>Generated by runedoc from lib/test/property/family\_sig.sml; do not edit.</sub>
