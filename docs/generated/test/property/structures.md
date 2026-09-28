# Structures and what they implement

[Property testing](README.md)

Every public structure of the library, with the signature it says it implements. Each has a page of
its own, which shows its members with the types it gives them; the signature's page says what they
mean. A signature of *none* means that no signature of the library names the structure, or that the
signature of the structure around it specifies it: its own page is then the only place it is
described.

`:>` means that the source seals the structure with the signature, so that its types are its own;
`:` that it matches it, which the test suite checks. Either way a program sees the members that the
signature names and no others, unless the structure is listed at the end of this page.

| Structure | Signature | Realisations | Status |  | Source |
| --- | --- | --- | --- | --- | --- |
| [`Arb`](str/Arb.md) | :> [`ARB`](sig/ARB.md) |  | required |  | [lib/test/property/arb.sml](../../../../lib/test/property/arb.sml) |
| [`BasisDataArb`](str/BasisDataArb.md) | :> [`BASIS_DATA_ARB`](sig/BASIS_DATA_ARB.md) |  | required |  | [lib/test/property/data.sml](../../../../lib/test/property/data.sml) |
| [`CharArb`](str/CharArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Char.char` | required | an application of `CharArbFn` | [lib/test/property/text.sml](../../../../lib/test/property/text.sml) |
| [`CharArray2Arb`](str/CharArray2Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharArray2.array` | required | an application of `MonoArray2ArbFn` | [lib/test/property/arrays2.sml](../../../../lib/test/property/arrays2.sml) |
| [`CharArrayArb`](str/CharArrayArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharArray.array` | required | an application of `MonoArrayArbFn` | [lib/test/property/text.sml](../../../../lib/test/property/text.sml) |
| [`CharArraySliceArb`](str/CharArraySliceArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharArraySlice.slice` | required | an application of `MonoArraySliceArbFn` | [lib/test/property/text.sml](../../../../lib/test/property/text.sml) |
| [`CharVectorArb`](str/CharVectorArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharVector.vector` | required | an application of `MonoVectorArbFn` | [lib/test/property/text.sml](../../../../lib/test/property/text.sml) |
| [`CharVectorSliceArb`](str/CharVectorSliceArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = CharVectorSlice.slice` | required | an application of `MonoVectorSliceArbFn` | [lib/test/property/text.sml](../../../../lib/test/property/text.sml) |
| [`Check`](str/Check.md) | :> [`CHECK`](sig/CHECK.md) |  | required |  | [lib/test/property/check.sml](../../../../lib/test/property/check.sml) |
| [`Co`](str/Co.md) | :> [`CO`](sig/CO.md) |  | required |  | [lib/test/property/co.sml](../../../../lib/test/property/co.sml) |
| [`DateArb`](str/DateArb.md) | :> [`DATE_ARB`](sig/DATE_ARB.md) |  | required |  | [lib/test/property/data.sml](../../../../lib/test/property/data.sml) |
| [`FixedIntArb`](str/FixedIntArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = FixedInt.int` | required | an application of `IntegerArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`Gen`](str/Gen.md) | :> [`GEN`](sig/GEN.md) |  | required |  | [lib/test/property/gen.sml](../../../../lib/test/property/gen.sml) |
| [`IEEERealArb`](str/IEEERealArb.md) | :> [`IEEE_REAL_ARB`](sig/IEEE_REAL_ARB.md) |  | required |  | [lib/test/property/data.sml](../../../../lib/test/property/data.sml) |
| [`INet6SockArb`](str/INet6SockArb.md) | :> [`INET6_SOCK_ARB`](sig/INET6_SOCK_ARB.md) |  | required |  | [lib/test/property/inet6.sml](../../../../lib/test/property/inet6.sml) |
| [`Int16Arb`](str/Int16Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int16.int` | required | an application of `IntegerArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`Int32Arb`](str/Int32Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int32.int` | required | an application of `IntegerArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`Int64Arb`](str/Int64Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int64.int` | required | an application of `IntegerArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`Int8Arb`](str/Int8Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int8.int` | required | an application of `IntegerArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`IntArb`](str/IntArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Int.int` | required | an application of `IntegerArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`IntArray2Arb`](str/IntArray2Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = IntArray2.array` | required | an application of `MonoArray2ArbFn` | [lib/test/property/arrays2.sml](../../../../lib/test/property/arrays2.sml) |
| [`IntInfArb`](str/IntInfArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = IntInf.int` | required | an application of `IntegerArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`LargeIntArb`](str/LargeIntArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = LargeInt.int` | required | an application of `IntegerArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`LargeRealArb`](str/LargeRealArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = LargeReal.real` | required | an application of `RealArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`LargeWordArb`](str/LargeWordArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = LargeWord.word` | required | an application of `WordArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`PositionArb`](str/PositionArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Position.int` | required | an application of `IntegerArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`Prop`](str/Prop.md) | :> [`PROP`](sig/PROP.md) |  | required |  | [lib/test/property/prop.sml](../../../../lib/test/property/prop.sml) |
| [`PropertyAround`](str/PropertyAround.md) | *none* |  | required |  | [lib/test/property/data.sml](../../../../lib/test/property/data.sml) |
| [`PropertyDimensions`](str/PropertyDimensions.md) | *none* |  | required |  | [lib/test/property/family.sml](../../../../lib/test/property/family.sml) |
| [`PropertyScratch`](str/PropertyScratch.md) | *none* |  | required |  | [lib/test/property/system.sml](../../../../lib/test/property/system.sml) |
| [`PropertySource`](str/PropertySource.md) | *none* |  | required |  | [lib/test/property/source.sml](../../../../lib/test/property/source.sml) |
| [`RandomArb`](str/RandomArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Random.gen` | required |  | [lib/test/property/data.sml](../../../../lib/test/property/data.sml) |
| [`Real32Arb`](str/Real32Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Real32.real` | required | an application of `RealArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`Real64Arb`](str/Real64Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Real64.real` | required | an application of `RealArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`RealArb`](str/RealArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Real.real` | required | an application of `RealArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`SML90Arb`](str/SML90Arb.md) | :> [`SML90_ARB`](sig/SML90_ARB.md) |  | required |  | [lib/test/property/sml90.sml](../../../../lib/test/property/sml90.sml) |
| [`Show`](str/Show.md) | :> [`SHOW`](sig/SHOW.md) |  | required |  | [lib/test/property/show.sml](../../../../lib/test/property/show.sml) |
| [`StringArb`](str/StringArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = String.string` | required | an application of `StringArbFn` | [lib/test/property/text.sml](../../../../lib/test/property/text.sml) |
| [`SubstringArb`](str/SubstringArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Substring.substring` | required | an application of `SubstringArbFn` | [lib/test/property/text.sml](../../../../lib/test/property/text.sml) |
| [`SysWordArb`](str/SysWordArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = SysWord.word` | required | an application of `WordArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`SystemArb`](str/SystemArb.md) | :> [`SYSTEM_ARB`](sig/SYSTEM_ARB.md) |  | required |  | [lib/test/property/system.sml](../../../../lib/test/property/system.sml) |
| [`TimeArb`](str/TimeArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Time.time` | required |  | [lib/test/property/data.sml](../../../../lib/test/property/data.sml) |
| [`WideCharArb`](str/WideCharArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = WideChar.char` | required | an application of `CharArbFn` | [lib/test/property/wide.sml](../../../../lib/test/property/wide.sml) |
| [`WideStringArb`](str/WideStringArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = WideString.string` | required | an application of `StringArbFn` | [lib/test/property/wide.sml](../../../../lib/test/property/wide.sml) |
| [`WideSubstringArb`](str/WideSubstringArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = WideSubstring.substring` | required | an application of `SubstringArbFn` | [lib/test/property/wide.sml](../../../../lib/test/property/wide.sml) |
| [`Word16Arb`](str/Word16Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word16.word` | required | an application of `WordArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`Word32Arb`](str/Word32Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word32.word` | required | an application of `WordArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`Word64Arb`](str/Word64Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word64.word` | required | an application of `WordArbFn` | [lib/test/property/sized.sml](../../../../lib/test/property/sized.sml) |
| [`Word8Arb`](str/Word8Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8.word` | required | an application of `WordArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |
| [`Word8Array2Arb`](str/Word8Array2Arb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8Array2.array` | required | an application of `MonoArray2ArbFn` | [lib/test/property/arrays2.sml](../../../../lib/test/property/arrays2.sml) |
| [`Word8ArrayArb`](str/Word8ArrayArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8Array.array` | required | an application of `MonoArrayArbFn` | [lib/test/property/bytes.sml](../../../../lib/test/property/bytes.sml) |
| [`Word8ArraySliceArb`](str/Word8ArraySliceArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8ArraySlice.slice` | required | an application of `MonoArraySliceArbFn` | [lib/test/property/bytes.sml](../../../../lib/test/property/bytes.sml) |
| [`Word8VectorArb`](str/Word8VectorArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8Vector.vector` | required | an application of `MonoVectorArbFn` | [lib/test/property/bytes.sml](../../../../lib/test/property/bytes.sml) |
| [`Word8VectorSliceArb`](str/Word8VectorSliceArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word8VectorSlice.slice` | required | an application of `MonoVectorSliceArbFn` | [lib/test/property/bytes.sml](../../../../lib/test/property/bytes.sml) |
| [`WordArb`](str/WordArb.md) | : [`ARB_OF`](sig/ARB_OF.md) | `where type t = Word.word` | required | an application of `WordArbFn` | [lib/test/property/numbers.sml](../../../../lib/test/property/numbers.sml) |

---

<sub>Generated by runedoc; do not edit.</sub>
