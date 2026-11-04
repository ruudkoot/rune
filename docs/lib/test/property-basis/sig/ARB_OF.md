# signature ARB_OF

[Property testing: the Basis Library's arbitraries](../README.md) &rsaquo; Property testing &rsaquo; **ARB_OF**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 39 |
| Documentation | 2 of 2 entries documented |
| Tests | not listed |
| Source | [lib/test/property/basis/family\_sig.sml](../../../../../lib/test/property/basis/family_sig.sml) |

## Synopsis

```sml
signature ARB_OF
structure CharArb : ARB_OF where type t = Char.char
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
structure LargeIntArb : ARB_OF where type t = LargeInt.int
structure LargeRealArb : ARB_OF where type t = LargeReal.real
structure LargeWordArb : ARB_OF where type t = LargeWord.word
structure PositionArb : ARB_OF where type t = Position.int
structure RandomArb : ARB_OF where type t = Random.gen
structure Real32Arb : ARB_OF where type t = Real32.real
structure Real64Arb : ARB_OF where type t = Real64.real
structure RealArb : ARB_OF where type t = Real.real
structure StringArb : ARB_OF where type t = String.string
structure SubstringArb : ARB_OF where type t = Substring.substring
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
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CharArb`](../str/CharArb.md) |  | [lib/test/property/basis/text.sml](../../../../../lib/test/property/basis/text.sml) |
| [`CharArray2Arb`](../str/CharArray2Arb.md) |  | [lib/test/property/basis/arrays2/chararray2.sml](../../../../../lib/test/property/basis/arrays2/chararray2.sml) |
| [`CharArrayArb`](../str/CharArrayArb.md) |  | [lib/test/property/basis/text.sml](../../../../../lib/test/property/basis/text.sml) |
| [`CharArraySliceArb`](../str/CharArraySliceArb.md) |  | [lib/test/property/basis/text.sml](../../../../../lib/test/property/basis/text.sml) |
| [`CharVectorArb`](../str/CharVectorArb.md) |  | [lib/test/property/basis/text.sml](../../../../../lib/test/property/basis/text.sml) |
| [`CharVectorSliceArb`](../str/CharVectorSliceArb.md) |  | [lib/test/property/basis/text.sml](../../../../../lib/test/property/basis/text.sml) |
| [`FixedIntArb`](../str/FixedIntArb.md) |  | [lib/test/property/basis/sized/fixedint.sml](../../../../../lib/test/property/basis/sized/fixedint.sml) |
| [`Int16Arb`](../str/Int16Arb.md) |  | [lib/test/property/basis/sized/int16.sml](../../../../../lib/test/property/basis/sized/int16.sml) |
| [`Int32Arb`](../str/Int32Arb.md) |  | [lib/test/property/basis/sized/int32.sml](../../../../../lib/test/property/basis/sized/int32.sml) |
| [`Int64Arb`](../str/Int64Arb.md) |  | [lib/test/property/basis/sized/int64.sml](../../../../../lib/test/property/basis/sized/int64.sml) |
| [`Int8Arb`](../str/Int8Arb.md) |  | [lib/test/property/basis/sized/int8.sml](../../../../../lib/test/property/basis/sized/int8.sml) |
| [`IntArb`](../str/IntArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`IntArray2Arb`](../str/IntArray2Arb.md) |  | [lib/test/property/basis/arrays2/intarray2.sml](../../../../../lib/test/property/basis/arrays2/intarray2.sml) |
| [`IntInfArb`](../str/IntInfArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`LargeIntArb`](../str/LargeIntArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`LargeRealArb`](../str/LargeRealArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`LargeWordArb`](../str/LargeWordArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`PositionArb`](../str/PositionArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`RandomArb`](../str/RandomArb.md) | The arbitrary of the generators of lib/random: the generator of a seed drawn as `Gen.word64` draws a word, shown as the text lib/random writes of it. | [lib/test/property/basis/data.sml](../../../../../lib/test/property/basis/data.sml) |
| [`Real32Arb`](../str/Real32Arb.md) |  | [lib/test/property/basis/sized/real32.sml](../../../../../lib/test/property/basis/sized/real32.sml) |
| [`Real64Arb`](../str/Real64Arb.md) |  | [lib/test/property/basis/sized/real64.sml](../../../../../lib/test/property/basis/sized/real64.sml) |
| [`RealArb`](../str/RealArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`StringArb`](../str/StringArb.md) |  | [lib/test/property/basis/text.sml](../../../../../lib/test/property/basis/text.sml) |
| [`SubstringArb`](../str/SubstringArb.md) |  | [lib/test/property/basis/text.sml](../../../../../lib/test/property/basis/text.sml) |
| [`SysWordArb`](../str/SysWordArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`TimeArb`](../str/TimeArb.md) | The arbitrary of `Time.time`: `Time.fromNanoseconds` of a number of nanoseconds drawn by the generator principle P1 over the range that the implementation's times hold, which the specification leaves to it and which is found by doubling a time until `Time` is raised (P12); by P2 where no such range is found below 2^200. | [lib/test/property/basis/data.sml](../../../../../lib/test/property/basis/data.sml) |
| [`WideCharArb`](../str/WideCharArb.md) |  | [lib/test/property/basis/wide/widechar.sml](../../../../../lib/test/property/basis/wide/widechar.sml) |
| [`WideStringArb`](../str/WideStringArb.md) |  | [lib/test/property/basis/wide/widestring.sml](../../../../../lib/test/property/basis/wide/widestring.sml) |
| [`WideSubstringArb`](../str/WideSubstringArb.md) |  | [lib/test/property/basis/wide/widesubstring.sml](../../../../../lib/test/property/basis/wide/widesubstring.sml) |
| [`Word16Arb`](../str/Word16Arb.md) |  | [lib/test/property/basis/sized/word16.sml](../../../../../lib/test/property/basis/sized/word16.sml) |
| [`Word32Arb`](../str/Word32Arb.md) |  | [lib/test/property/basis/sized/word32.sml](../../../../../lib/test/property/basis/sized/word32.sml) |
| [`Word64Arb`](../str/Word64Arb.md) |  | [lib/test/property/basis/sized/word64.sml](../../../../../lib/test/property/basis/sized/word64.sml) |
| [`Word8Arb`](../str/Word8Arb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |
| [`Word8Array2Arb`](../str/Word8Array2Arb.md) |  | [lib/test/property/basis/arrays2/word8array2.sml](../../../../../lib/test/property/basis/arrays2/word8array2.sml) |
| [`Word8ArrayArb`](../str/Word8ArrayArb.md) |  | [lib/test/property/basis/bytes.sml](../../../../../lib/test/property/basis/bytes.sml) |
| [`Word8ArraySliceArb`](../str/Word8ArraySliceArb.md) |  | [lib/test/property/basis/bytes.sml](../../../../../lib/test/property/basis/bytes.sml) |
| [`Word8VectorArb`](../str/Word8VectorArb.md) |  | [lib/test/property/basis/bytes.sml](../../../../../lib/test/property/basis/bytes.sml) |
| [`Word8VectorSliceArb`](../str/Word8VectorSliceArb.md) |  | [lib/test/property/basis/bytes.sml](../../../../../lib/test/property/basis/bytes.sml) |
| [`WordArb`](../str/WordArb.md) |  | [lib/test/property/basis/numbers.sml](../../../../../lib/test/property/basis/numbers.sml) |

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

<sub>Generated by runedoc from lib/test/property/basis/family\_sig.sml; do not edit.</sub>
