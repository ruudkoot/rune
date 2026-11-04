# Structures and what they implement

[Property testing: the Basis Library's arbitraries](README.md)

Every public structure of the library, with the signature it says it implements. Each has a page of
its own, which shows its members with the types it gives them; the signature's page says what they
mean. A signature of *none* means that no signature of the library names the structure: its own page
is then the only place it is described. *in* before a signature means that the signature of the
structure around it specifies this one.

`:>` before a signature means that the source seals the structure with it, so that its types are its
own; `:` that it matches it, which the test suite checks. Either way a program sees the members that
the signature names and no others.

| Structure |  | Signature | Realisations |  | Source |
| --- | --- | --- | --- | --- | --- |
| [`BasisDataArb`](str/BasisDataArb.md) | :> | [`BASIS_DATA_ARB`](sig/BASIS_DATA_ARB.md) |  |  | [lib/test/property/basis/data.sml](../../../../lib/test/property/basis/data.sml) |
| [`CharArb`](str/CharArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Char.char` | an application of `CharArbFn` | [lib/test/property/basis/text.sml](../../../../lib/test/property/basis/text.sml) |
| [`CharArray2Arb`](str/CharArray2Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharArray2.array` | an application of `MonoArray2ArbFn` | [lib/test/property/basis/arrays2/chararray2.sml](../../../../lib/test/property/basis/arrays2/chararray2.sml) |
| [`CharArrayArb`](str/CharArrayArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharArray.array` | an application of `MonoArrayArbFn` | [lib/test/property/basis/text.sml](../../../../lib/test/property/basis/text.sml) |
| [`CharArraySliceArb`](str/CharArraySliceArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharArraySlice.slice` | an application of `MonoArraySliceArbFn` | [lib/test/property/basis/text.sml](../../../../lib/test/property/basis/text.sml) |
| [`CharVectorArb`](str/CharVectorArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharVector.vector` | an application of `MonoVectorArbFn` | [lib/test/property/basis/text.sml](../../../../lib/test/property/basis/text.sml) |
| [`CharVectorSliceArb`](str/CharVectorSliceArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharVectorSlice.slice` | an application of `MonoVectorSliceArbFn` | [lib/test/property/basis/text.sml](../../../../lib/test/property/basis/text.sml) |
| [`DateArb`](str/DateArb.md) | :> | [`DATE_ARB`](sig/DATE_ARB.md) |  |  | [lib/test/property/basis/data.sml](../../../../lib/test/property/basis/data.sml) |
| [`FixedIntArb`](str/FixedIntArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = FixedInt.int` | an application of `IntegerArbFn` | [lib/test/property/basis/sized/fixedint.sml](../../../../lib/test/property/basis/sized/fixedint.sml) |
| [`IEEERealArb`](str/IEEERealArb.md) | :> | [`IEEE_REAL_ARB`](sig/IEEE_REAL_ARB.md) |  |  | [lib/test/property/basis/data.sml](../../../../lib/test/property/basis/data.sml) |
| [`INet6SockArb`](str/INet6SockArb.md) | :> | [`INET6_SOCK_ARB`](sig/INET6_SOCK_ARB.md) |  |  | [lib/test/property/basis/inet6.sml](../../../../lib/test/property/basis/inet6.sml) |
| [`Int16Arb`](str/Int16Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int16.int` | an application of `IntegerArbFn` | [lib/test/property/basis/sized/int16.sml](../../../../lib/test/property/basis/sized/int16.sml) |
| [`Int32Arb`](str/Int32Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int32.int` | an application of `IntegerArbFn` | [lib/test/property/basis/sized/int32.sml](../../../../lib/test/property/basis/sized/int32.sml) |
| [`Int64Arb`](str/Int64Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int64.int` | an application of `IntegerArbFn` | [lib/test/property/basis/sized/int64.sml](../../../../lib/test/property/basis/sized/int64.sml) |
| [`Int8Arb`](str/Int8Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int8.int` | an application of `IntegerArbFn` | [lib/test/property/basis/sized/int8.sml](../../../../lib/test/property/basis/sized/int8.sml) |
| [`IntArb`](str/IntArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int.int` | an application of `IntegerArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`IntArray2Arb`](str/IntArray2Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = IntArray2.array` | an application of `MonoArray2ArbFn` | [lib/test/property/basis/arrays2/intarray2.sml](../../../../lib/test/property/basis/arrays2/intarray2.sml) |
| [`IntInfArb`](str/IntInfArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = IntInf.int` | an application of `IntegerArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`LargeIntArb`](str/LargeIntArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = LargeInt.int` | an application of `IntegerArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`LargeRealArb`](str/LargeRealArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = LargeReal.real` | an application of `RealArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`LargeWordArb`](str/LargeWordArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = LargeWord.word` | an application of `WordArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`PositionArb`](str/PositionArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Position.int` | an application of `IntegerArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`RandomArb`](str/RandomArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Random.gen` |  | [lib/test/property/basis/data.sml](../../../../lib/test/property/basis/data.sml) |
| [`Real32Arb`](str/Real32Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Real32.real` | an application of `RealArbFn` | [lib/test/property/basis/sized/real32.sml](../../../../lib/test/property/basis/sized/real32.sml) |
| [`Real64Arb`](str/Real64Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Real64.real` | an application of `RealArbFn` | [lib/test/property/basis/sized/real64.sml](../../../../lib/test/property/basis/sized/real64.sml) |
| [`RealArb`](str/RealArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Real.real` | an application of `RealArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`SML90Arb`](str/SML90Arb.md) | :> | [`SML90_ARB`](sig/SML90_ARB.md) |  |  | [lib/test/property/basis/sml90.sml](../../../../lib/test/property/basis/sml90.sml) |
| [`StringArb`](str/StringArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = String.string` | an application of `StringArbFn` | [lib/test/property/basis/text.sml](../../../../lib/test/property/basis/text.sml) |
| [`SubstringArb`](str/SubstringArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Substring.substring` | an application of `SubstringArbFn` | [lib/test/property/basis/text.sml](../../../../lib/test/property/basis/text.sml) |
| [`SysWordArb`](str/SysWordArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = SysWord.word` | an application of `WordArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`SystemArb`](str/SystemArb.md) | :> | [`SYSTEM_ARB`](sig/SYSTEM_ARB.md) |  |  | [lib/test/property/basis/system.sml](../../../../lib/test/property/basis/system.sml) |
| [`TimeArb`](str/TimeArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Time.time` |  | [lib/test/property/basis/data.sml](../../../../lib/test/property/basis/data.sml) |
| [`WideCharArb`](str/WideCharArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = WideChar.char` | an application of `CharArbFn` | [lib/test/property/basis/wide/widechar.sml](../../../../lib/test/property/basis/wide/widechar.sml) |
| [`WideStringArb`](str/WideStringArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = WideString.string` | an application of `StringArbFn` | [lib/test/property/basis/wide/widestring.sml](../../../../lib/test/property/basis/wide/widestring.sml) |
| [`WideSubstringArb`](str/WideSubstringArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = WideSubstring.substring` | an application of `SubstringArbFn` | [lib/test/property/basis/wide/widesubstring.sml](../../../../lib/test/property/basis/wide/widesubstring.sml) |
| [`Word16Arb`](str/Word16Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word16.word` | an application of `WordArbFn` | [lib/test/property/basis/sized/word16.sml](../../../../lib/test/property/basis/sized/word16.sml) |
| [`Word32Arb`](str/Word32Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word32.word` | an application of `WordArbFn` | [lib/test/property/basis/sized/word32.sml](../../../../lib/test/property/basis/sized/word32.sml) |
| [`Word64Arb`](str/Word64Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word64.word` | an application of `WordArbFn` | [lib/test/property/basis/sized/word64.sml](../../../../lib/test/property/basis/sized/word64.sml) |
| [`Word8Arb`](str/Word8Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8.word` | an application of `WordArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |
| [`Word8Array2Arb`](str/Word8Array2Arb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8Array2.array` | an application of `MonoArray2ArbFn` | [lib/test/property/basis/arrays2/word8array2.sml](../../../../lib/test/property/basis/arrays2/word8array2.sml) |
| [`Word8ArrayArb`](str/Word8ArrayArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8Array.array` | an application of `MonoArrayArbFn` | [lib/test/property/basis/bytes.sml](../../../../lib/test/property/basis/bytes.sml) |
| [`Word8ArraySliceArb`](str/Word8ArraySliceArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8ArraySlice.slice` | an application of `MonoArraySliceArbFn` | [lib/test/property/basis/bytes.sml](../../../../lib/test/property/basis/bytes.sml) |
| [`Word8VectorArb`](str/Word8VectorArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8Vector.vector` | an application of `MonoVectorArbFn` | [lib/test/property/basis/bytes.sml](../../../../lib/test/property/basis/bytes.sml) |
| [`Word8VectorSliceArb`](str/Word8VectorSliceArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8VectorSlice.slice` | an application of `MonoVectorSliceArbFn` | [lib/test/property/basis/bytes.sml](../../../../lib/test/property/basis/bytes.sml) |
| [`WordArb`](str/WordArb.md) | : | [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word.word` | an application of `WordArbFn` | [lib/test/property/basis/numbers.sml](../../../../lib/test/property/basis/numbers.sml) |

---

<sub>Generated by runedoc; do not edit.</sub>
