# signature ARB_OF

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; **ARB_OF**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 134 |
| Documentation | 2 of 2 entries documented |
| Tests | not listed |
| Source | [lib/test/property/family\_sig.sml](../../../../../lib/test/property/family_sig.sml) |

## Synopsis

```sml
signature ARB_OF
structure BoolArray2Arb : ARB_OF where type t = BoolArray2.array
structure BoolArrayArb : ARB_OF where type t = BoolArray.array
structure BoolArraySliceArb : ARB_OF where type t = BoolArraySlice.slice
structure BoolVectorArb : ARB_OF where type t = BoolVector.vector
structure BoolVectorSliceArb : ARB_OF where type t = BoolVectorSlice.slice
structure CharArb : ARB_OF where type t = Char.char
functor CharArbFn (...) : ARB_OF where type t = C.char
structure CharArray2Arb : ARB_OF where type t = CharArray2.array
structure CharArrayArb : ARB_OF where type t = CharArray.array
structure CharArraySliceArb : ARB_OF where type t = CharArraySlice.slice
structure CharVectorArb : ARB_OF where type t = CharVector.vector
structure CharVectorSliceArb : ARB_OF where type t = CharVectorSlice.slice
structure FixedIntArb : ARB_OF where type t = FixedInt.int
structure Int16Arb : ARB_OF where type t = Int16.int
structure Int16Array2Arb : ARB_OF where type t = Int16Array2.array
structure Int16ArrayArb : ARB_OF where type t = Int16Array.array
structure Int16ArraySliceArb : ARB_OF where type t = Int16ArraySlice.slice
structure Int16VectorArb : ARB_OF where type t = Int16Vector.vector
structure Int16VectorSliceArb : ARB_OF where type t = Int16VectorSlice.slice
structure Int32Arb : ARB_OF where type t = Int32.int
structure Int32Array2Arb : ARB_OF where type t = Int32Array2.array
structure Int32ArrayArb : ARB_OF where type t = Int32Array.array
structure Int32ArraySliceArb : ARB_OF where type t = Int32ArraySlice.slice
structure Int32VectorArb : ARB_OF where type t = Int32Vector.vector
structure Int32VectorSliceArb : ARB_OF where type t = Int32VectorSlice.slice
structure Int64Arb : ARB_OF where type t = Int64.int
structure Int64Array2Arb : ARB_OF where type t = Int64Array2.array
structure Int64ArrayArb : ARB_OF where type t = Int64Array.array
structure Int64ArraySliceArb : ARB_OF where type t = Int64ArraySlice.slice
structure Int64VectorArb : ARB_OF where type t = Int64Vector.vector
structure Int64VectorSliceArb : ARB_OF where type t = Int64VectorSlice.slice
structure Int8Arb : ARB_OF where type t = Int8.int
structure Int8Array2Arb : ARB_OF where type t = Int8Array2.array
structure Int8ArrayArb : ARB_OF where type t = Int8Array.array
structure Int8ArraySliceArb : ARB_OF where type t = Int8ArraySlice.slice
structure Int8VectorArb : ARB_OF where type t = Int8Vector.vector
structure Int8VectorSliceArb : ARB_OF where type t = Int8VectorSlice.slice
structure IntArb : ARB_OF where type t = Int.int
structure IntArray2Arb : ARB_OF where type t = IntArray2.array
structure IntArrayArb : ARB_OF where type t = IntArray.array
structure IntArraySliceArb : ARB_OF where type t = IntArraySlice.slice
structure IntInfArb : ARB_OF where type t = IntInf.int
structure IntVectorArb : ARB_OF where type t = IntVector.vector
structure IntVectorSliceArb : ARB_OF where type t = IntVectorSlice.slice
functor IntegerArbFn (...) : ARB_OF where type t = I.int
structure LargeIntArb : ARB_OF where type t = LargeInt.int
structure LargeIntArray2Arb : ARB_OF where type t = LargeIntArray2.array
structure LargeIntArrayArb : ARB_OF where type t = LargeIntArray.array
structure LargeIntArraySliceArb : ARB_OF where type t = LargeIntArraySlice.slice
structure LargeIntVectorArb : ARB_OF where type t = LargeIntVector.vector
structure LargeIntVectorSliceArb : ARB_OF where type t = LargeIntVectorSlice.slice
structure LargeRealArb : ARB_OF where type t = LargeReal.real
structure LargeRealArray2Arb : ARB_OF where type t = LargeRealArray2.array
structure LargeRealArrayArb : ARB_OF where type t = LargeRealArray.array
structure LargeRealArraySliceArb : ARB_OF where type t = LargeRealArraySlice.slice
structure LargeRealVectorArb : ARB_OF where type t = LargeRealVector.vector
structure LargeRealVectorSliceArb : ARB_OF where type t = LargeRealVectorSlice.slice
structure LargeWordArb : ARB_OF where type t = LargeWord.word
structure LargeWordArray2Arb : ARB_OF where type t = LargeWordArray2.array
structure LargeWordArrayArb : ARB_OF where type t = LargeWordArray.array
structure LargeWordArraySliceArb : ARB_OF where type t = LargeWordArraySlice.slice
structure LargeWordVectorArb : ARB_OF where type t = LargeWordVector.vector
structure LargeWordVectorSliceArb : ARB_OF where type t = LargeWordVectorSlice.slice
functor MonoArray2ArbFn (...) : ARB_OF where type t = A.array
functor MonoArrayArbFn (...) : ARB_OF where type t = A.array
functor MonoArraySliceArbFn (...) : ARB_OF where type t = S.slice
functor MonoVectorArbFn (...) : ARB_OF where type t = V.vector
functor MonoVectorSliceArbFn (...) : ARB_OF where type t = S.slice
structure PositionArb : ARB_OF where type t = Position.int
structure RandomArb : ARB_OF where type t = Random.gen
structure Real32Arb : ARB_OF where type t = Real32.real
structure Real32Array2Arb : ARB_OF where type t = Real32Array2.array
structure Real32ArrayArb : ARB_OF where type t = Real32Array.array
structure Real32ArraySliceArb : ARB_OF where type t = Real32ArraySlice.slice
structure Real32VectorArb : ARB_OF where type t = Real32Vector.vector
structure Real32VectorSliceArb : ARB_OF where type t = Real32VectorSlice.slice
structure Real64Arb : ARB_OF where type t = Real64.real
structure Real64Array2Arb : ARB_OF where type t = Real64Array2.array
structure Real64ArrayArb : ARB_OF where type t = Real64Array.array
structure Real64ArraySliceArb : ARB_OF where type t = Real64ArraySlice.slice
structure Real64VectorArb : ARB_OF where type t = Real64Vector.vector
structure Real64VectorSliceArb : ARB_OF where type t = Real64VectorSlice.slice
structure RealArb : ARB_OF where type t = Real.real
functor RealArbFn (...) : ARB_OF where type t = R.real
structure RealArray2Arb : ARB_OF where type t = RealArray2.array
structure RealArrayArb : ARB_OF where type t = RealArray.array
structure RealArraySliceArb : ARB_OF where type t = RealArraySlice.slice
structure RealVectorArb : ARB_OF where type t = RealVector.vector
structure RealVectorSliceArb : ARB_OF where type t = RealVectorSlice.slice
structure StringArb : ARB_OF where type t = String.string
functor StringArbFn (...) : ARB_OF where type t = S.string
structure SubstringArb : ARB_OF where type t = Substring.substring
functor SubstringArbFn (...) : ARB_OF where type t = S.substring
structure SysWordArb : ARB_OF where type t = SysWord.word
structure TimeArb : ARB_OF where type t = Time.time
structure WideCharArb : ARB_OF where type t = WideChar.char
structure WideCharArray2Arb : ARB_OF where type t = WideCharArray2.array
structure WideCharArrayArb : ARB_OF where type t = WideCharArray.array
structure WideCharArraySliceArb : ARB_OF where type t = WideCharArraySlice.slice
structure WideCharVectorArb : ARB_OF where type t = WideCharVector.vector
structure WideCharVectorSliceArb : ARB_OF where type t = WideCharVectorSlice.slice
structure WideStringArb : ARB_OF where type t = WideString.string
structure WideSubstringArb : ARB_OF where type t = WideSubstring.substring
structure Word16Arb : ARB_OF where type t = Word16.word
structure Word16Array2Arb : ARB_OF where type t = Word16Array2.array
structure Word16ArrayArb : ARB_OF where type t = Word16Array.array
structure Word16ArraySliceArb : ARB_OF where type t = Word16ArraySlice.slice
structure Word16VectorArb : ARB_OF where type t = Word16Vector.vector
structure Word16VectorSliceArb : ARB_OF where type t = Word16VectorSlice.slice
structure Word32Arb : ARB_OF where type t = Word32.word
structure Word32Array2Arb : ARB_OF where type t = Word32Array2.array
structure Word32ArrayArb : ARB_OF where type t = Word32Array.array
structure Word32ArraySliceArb : ARB_OF where type t = Word32ArraySlice.slice
structure Word32VectorArb : ARB_OF where type t = Word32Vector.vector
structure Word32VectorSliceArb : ARB_OF where type t = Word32VectorSlice.slice
structure Word64Arb : ARB_OF where type t = Word64.word
structure Word64Array2Arb : ARB_OF where type t = Word64Array2.array
structure Word64ArrayArb : ARB_OF where type t = Word64Array.array
structure Word64ArraySliceArb : ARB_OF where type t = Word64ArraySlice.slice
structure Word64VectorArb : ARB_OF where type t = Word64Vector.vector
structure Word64VectorSliceArb : ARB_OF where type t = Word64VectorSlice.slice
structure Word8Arb : ARB_OF where type t = Word8.word
structure Word8Array2Arb : ARB_OF where type t = Word8Array2.array
structure Word8ArrayArb : ARB_OF where type t = Word8Array.array
structure Word8ArraySliceArb : ARB_OF where type t = Word8ArraySlice.slice
structure Word8VectorArb : ARB_OF where type t = Word8Vector.vector
structure Word8VectorSliceArb : ARB_OF where type t = Word8VectorSlice.slice
structure WordArb : ARB_OF where type t = Word.word
functor WordArbFn (...) : ARB_OF where type t = W.word
structure WordArray2Arb : ARB_OF where type t = WordArray2.array
structure WordArrayArb : ARB_OF where type t = WordArray.array
structure WordArraySliceArb : ARB_OF where type t = WordArraySlice.slice
structure WordVectorArb : ARB_OF where type t = WordVector.vector
structure WordVectorSliceArb : ARB_OF where type t = WordVectorSlice.slice
```

| Implementation |  | Source |
| --- | --- | --- |
| [`BoolArray2Arb`](../str/BoolArray2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`BoolArrayArb`](../str/BoolArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`BoolArraySliceArb`](../str/BoolArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`BoolVectorArb`](../str/BoolVectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`BoolVectorSliceArb`](../str/BoolVectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`CharArb`](../str/CharArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| `CharArbFn` | The arbitrary of the characters of a structure of `CHAR`, by the generator principle P5, as [`Gen.code`](../sig/GEN.md#val-code) draws their codes. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`CharArray2Arb`](../str/CharArray2Arb.md) |  | [lib/test/property/arrays2.sml](../../../../../lib/test/property/arrays2.sml) |
| [`CharArrayArb`](../str/CharArrayArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| [`CharArraySliceArb`](../str/CharArraySliceArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| [`CharVectorArb`](../str/CharVectorArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| [`CharVectorSliceArb`](../str/CharVectorSliceArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| [`FixedIntArb`](../str/FixedIntArb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int16Arb`](../str/Int16Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int16Array2Arb`](../str/Int16Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int16ArrayArb`](../str/Int16ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int16ArraySliceArb`](../str/Int16ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int16VectorArb`](../str/Int16VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int16VectorSliceArb`](../str/Int16VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int32Arb`](../str/Int32Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int32Array2Arb`](../str/Int32Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int32ArrayArb`](../str/Int32ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int32ArraySliceArb`](../str/Int32ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int32VectorArb`](../str/Int32VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int32VectorSliceArb`](../str/Int32VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int64Arb`](../str/Int64Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int64Array2Arb`](../str/Int64Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int64ArrayArb`](../str/Int64ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int64ArraySliceArb`](../str/Int64ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int64VectorArb`](../str/Int64VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int64VectorSliceArb`](../str/Int64VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int8Arb`](../str/Int8Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Int8Array2Arb`](../str/Int8Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int8ArrayArb`](../str/Int8ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int8ArraySliceArb`](../str/Int8ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int8VectorArb`](../str/Int8VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Int8VectorSliceArb`](../str/Int8VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`IntArb`](../str/IntArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`IntArray2Arb`](../str/IntArray2Arb.md) |  | [lib/test/property/arrays2.sml](../../../../../lib/test/property/arrays2.sml) |
| [`IntArrayArb`](../str/IntArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`IntArraySliceArb`](../str/IntArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`IntInfArb`](../str/IntInfArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`IntVectorArb`](../str/IntVectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`IntVectorSliceArb`](../str/IntVectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| `IntegerArbFn` | The arbitrary of the integers of a structure of `INTEGER`, by the generator principles P1 and P2: small, on an edge, or anywhere in the range, a third each; an `IntInf` without bounds by [`Gen.intInf`](../sig/GEN.md#val-intinf). | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`LargeIntArb`](../str/LargeIntArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`LargeIntArray2Arb`](../str/LargeIntArray2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeIntArrayArb`](../str/LargeIntArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeIntArraySliceArb`](../str/LargeIntArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeIntVectorArb`](../str/LargeIntVectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeIntVectorSliceArb`](../str/LargeIntVectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeRealArb`](../str/LargeRealArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`LargeRealArray2Arb`](../str/LargeRealArray2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeRealArrayArb`](../str/LargeRealArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeRealArraySliceArb`](../str/LargeRealArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeRealVectorArb`](../str/LargeRealVectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeRealVectorSliceArb`](../str/LargeRealVectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeWordArb`](../str/LargeWordArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`LargeWordArray2Arb`](../str/LargeWordArray2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeWordArrayArb`](../str/LargeWordArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeWordArraySliceArb`](../str/LargeWordArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeWordVectorArb`](../str/LargeWordVectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`LargeWordVectorSliceArb`](../str/LargeWordVectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| `MonoArray2ArbFn` | The arbitrary of the two-dimensional arrays of a structure of `MONO_ARRAY2`, as [`Arb.array2`](../sig/ARB.md#val-array2) draws them. `name` is the structure's name. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| `MonoArrayArbFn` | The arbitrary of the arrays of a structure of `MONO_ARRAY`, as [`MonoVectorArbFn`](../fun/MonoVectorArbFn.md) draws vectors: a fresh array at every draw, compared by its elements. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| `MonoArraySliceArbFn` | The arbitrary of the slices of a structure of `MONO_ARRAY_SLICE`, as [`MonoVectorSliceArbFn`](../fun/MonoVectorSliceArbFn.md) draws them, over a fresh array of `array` at every draw. `name` is the structure's name. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| `MonoVectorArbFn` | The arbitrary of the vectors of a structure of `MONO_VECTOR`: lists of `elem`, by the generator principle P6. `name` is the structure's name, which the printer writes. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| `MonoVectorSliceArbFn` | The arbitrary of the slices of a structure of `MONO_VECTOR_SLICE`: a vector of `vector`, and a start and a length within it, compared as [`Arb.vectorSlice`](../sig/ARB.md#val-vectorslice) compares slices. `name` is the structure's name. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`PositionArb`](../str/PositionArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`RandomArb`](../str/RandomArb.md) | The arbitrary of the generators of lib/random: the generator of a seed drawn as [`Gen.word64`](../sig/GEN.md#val-word64) draws a word, shown as the text lib/random writes of it. | [lib/test/property/data.sml](../../../../../lib/test/property/data.sml) |
| [`Real32Arb`](../str/Real32Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Real32Array2Arb`](../str/Real32Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real32ArrayArb`](../str/Real32ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real32ArraySliceArb`](../str/Real32ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real32VectorArb`](../str/Real32VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real32VectorSliceArb`](../str/Real32VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real64Arb`](../str/Real64Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Real64Array2Arb`](../str/Real64Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real64ArrayArb`](../str/Real64ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real64ArraySliceArb`](../str/Real64ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real64VectorArb`](../str/Real64VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Real64VectorSliceArb`](../str/Real64VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`RealArb`](../str/RealArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| `RealArbFn` | The arbitrary of the reals of a structure of `REAL`, by the generator principle P4: a special one, a small one, or any bit pattern, a third each. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`RealArray2Arb`](../str/RealArray2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`RealArrayArb`](../str/RealArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`RealArraySliceArb`](../str/RealArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`RealVectorArb`](../str/RealVectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`RealVectorSliceArb`](../str/RealVectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`StringArb`](../str/StringArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| `StringArbFn` | The arbitrary of the strings of a structure of `STRING`: lists of the characters of `char`, by the generator principle P6. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`SubstringArb`](../str/SubstringArb.md) |  | [lib/test/property/text.sml](../../../../../lib/test/property/text.sml) |
| `SubstringArbFn` | The arbitrary of the substrings of a structure of `SUBSTRING`: a string of `string`, and a start and a length within it. `name` is the structure's name, which the printer writes. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`SysWordArb`](../str/SysWordArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`TimeArb`](../str/TimeArb.md) | The arbitrary of `Time.time`: `Time.fromNanoseconds` of a number of nanoseconds drawn by the generator principle P1 over the range that the implementation's times hold, which the specification leaves to it and which is found by doubling a time until `Time` is raised (P12); by P2 where no such range is found below 2^200. | [lib/test/property/data.sml](../../../../../lib/test/property/data.sml) |
| [`WideCharArb`](../str/WideCharArb.md) |  | [lib/test/property/wide.sml](../../../../../lib/test/property/wide.sml) |
| [`WideCharArray2Arb`](../str/WideCharArray2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WideCharArrayArb`](../str/WideCharArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WideCharArraySliceArb`](../str/WideCharArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WideCharVectorArb`](../str/WideCharVectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WideCharVectorSliceArb`](../str/WideCharVectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WideStringArb`](../str/WideStringArb.md) |  | [lib/test/property/wide.sml](../../../../../lib/test/property/wide.sml) |
| [`WideSubstringArb`](../str/WideSubstringArb.md) |  | [lib/test/property/wide.sml](../../../../../lib/test/property/wide.sml) |
| [`Word16Arb`](../str/Word16Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Word16Array2Arb`](../str/Word16Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word16ArrayArb`](../str/Word16ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word16ArraySliceArb`](../str/Word16ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word16VectorArb`](../str/Word16VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word16VectorSliceArb`](../str/Word16VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word32Arb`](../str/Word32Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Word32Array2Arb`](../str/Word32Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word32ArrayArb`](../str/Word32ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word32ArraySliceArb`](../str/Word32ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word32VectorArb`](../str/Word32VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word32VectorSliceArb`](../str/Word32VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word64Arb`](../str/Word64Arb.md) |  | [lib/test/property/sized.sml](../../../../../lib/test/property/sized.sml) |
| [`Word64Array2Arb`](../str/Word64Array2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word64ArrayArb`](../str/Word64ArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word64ArraySliceArb`](../str/Word64ArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word64VectorArb`](../str/Word64VectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word64VectorSliceArb`](../str/Word64VectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`Word8Arb`](../str/Word8Arb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| [`Word8Array2Arb`](../str/Word8Array2Arb.md) |  | [lib/test/property/arrays2.sml](../../../../../lib/test/property/arrays2.sml) |
| [`Word8ArrayArb`](../str/Word8ArrayArb.md) |  | [lib/test/property/bytes.sml](../../../../../lib/test/property/bytes.sml) |
| [`Word8ArraySliceArb`](../str/Word8ArraySliceArb.md) |  | [lib/test/property/bytes.sml](../../../../../lib/test/property/bytes.sml) |
| [`Word8VectorArb`](../str/Word8VectorArb.md) |  | [lib/test/property/bytes.sml](../../../../../lib/test/property/bytes.sml) |
| [`Word8VectorSliceArb`](../str/Word8VectorSliceArb.md) |  | [lib/test/property/bytes.sml](../../../../../lib/test/property/bytes.sml) |
| [`WordArb`](../str/WordArb.md) |  | [lib/test/property/numbers.sml](../../../../../lib/test/property/numbers.sml) |
| `WordArbFn` | The arbitrary of the words of a structure of `WORD`, by the generator principle P3: small, on an edge (0, 1, the largest, powers of two and their neighbours), or anywhere, a third each. The words are at most 64 bits. | [lib/test/property/family.sml](../../../../../lib/test/property/family.sml) |
| [`WordArray2Arb`](../str/WordArray2Arb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WordArrayArb`](../str/WordArrayArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WordArraySliceArb`](../str/WordArraySliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WordVectorArb`](../str/WordVectorArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |
| [`WordVectorSliceArb`](../str/WordVectorSliceArb.md) |  | [lib/test/property/sequences.sml](../../../../../lib/test/property/sequences.sml) |

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
