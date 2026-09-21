# Structures and what they implement

[The Standard ML Basis Library](README.md)

Every public structure of the library that says which signature it implements. A structure is
documented on the page of its signature. `:>` means that the source seals the structure with the
signature, so that its types are its own; `:` that it matches it, which the test suite checks.
Either way a program sees the members that the signature names and no others, unless the structure
is listed at the end of this page.

| Structure | Signature | Realisations | Status |  | Source |
| --- | --- | --- | --- | --- | --- |
| `Array` | : [`ARRAY`](sig/ARRAY.md) |  | required |  | [lib/basis/array.sml](../../../lib/basis/array.sml) |
| `Array2` | : [`ARRAY2`](sig/ARRAY2.md) |  | optional |  | [lib/basis/array2.sml](../../../lib/basis/array2.sml) |
| `ArraySlice` | : [`ARRAY_SLICE`](sig/ARRAY_SLICE.md) |  | required |  | [lib/basis/arrayslice.sml](../../../lib/basis/arrayslice.sml) |
| `BinIO` | : [`BIN_IO`](sig/BIN_IO.md) |  | required |  | [lib/basis/binio.sml](../../../lib/basis/binio.sml) |
| `BinIO` | : [`IMPERATIVE_IO`](sig/IMPERATIVE_IO.md) |  | required |  | [lib/basis/binio.sml](../../../lib/basis/binio.sml) |
| `BinIO.StreamIO` | : [`STREAM_IO`](sig/STREAM_IO.md) | `where type vector = Word8Vector.vector where type elem = Word8.word where type reader = BinPrimIO.reader where type writer = BinPrimIO.writer where type pos = Position.int` | required | an application of `RuneStreamIOFn` | [lib/basis/binio.sml](../../../lib/basis/binio.sml) |
| `BinPrimIO` | : [`PRIM_IO`](sig/PRIM_IO.md) | `where type array = Word8Array.array where type vector = Word8Vector.vector where type elem = Word8.word where type pos = Position.int where type vector_slice = Word8VectorSlice.slice where type array_slice = Word8ArraySlice.slice` | required | an application of `RunePrimIOFn` | [lib/basis/binprimio.sml](../../../lib/basis/binprimio.sml) |
| `Bool` | : [`BOOL`](sig/BOOL.md) |  | required |  | [lib/basis/bool.sml](../../../lib/basis/bool.sml) |
| `BoolArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = BoolVector.vector where type elem = bool` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_bool.sml](../../../lib/basis/mono_bool.sml) |
| `BoolArray2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = BoolVector.vector where type elem = bool` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_bool.sml](../../../lib/basis/mono_bool.sml) |
| `BoolArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = BoolVector.vector where type vector_slice = BoolVectorSlice.slice where type array = BoolArray.array where type elem = bool` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_bool.sml](../../../lib/basis/mono_bool.sml) |
| `BoolVector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = bool` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_bool.sml](../../../lib/basis/mono_bool.sml) |
| `BoolVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = BoolVector.vector where type elem = bool` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_bool.sml](../../../lib/basis/mono_bool.sml) |
| `Byte` | : [`BYTE`](sig/BYTE.md) |  | required |  | [lib/basis/byte.sml](../../../lib/basis/byte.sml) |
| `Char` | : [`CHAR`](sig/CHAR.md) | `where type char = char where type string = String.string` | required |  | [lib/basis/char.sml](../../../lib/basis/char.sml) |
| `CharArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = CharVector.vector where type elem = char` | required | an application of `RuneMonoArrayFn` | [lib/basis/chararray.sml](../../../lib/basis/chararray.sml) |
| `CharArray2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = CharVector.vector where type elem = char` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/chararray2.sml](../../../lib/basis/chararray2.sml) |
| `CharArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = CharVector.vector where type vector_slice = CharVectorSlice.slice where type array = CharArray.array where type elem = char` | required | an application of `RuneMonoArraySliceFn` | [lib/basis/chararrayslice.sml](../../../lib/basis/chararrayslice.sml) |
| `CharVector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type vector = String.string where type elem = char` | required | an application of `RuneStringVectorFn` | [lib/basis/charvector.sml](../../../lib/basis/charvector.sml) |
| `CharVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type slice = Substring.substring where type vector = String.string where type elem = char` | required |  | [lib/basis/charvectorslice.sml](../../../lib/basis/charvectorslice.sml) |
| `CommandLine` | : [`COMMAND_LINE`](sig/COMMAND_LINE.md) |  | required |  | [lib/basis/commandline.sml](../../../lib/basis/commandline.sml) |
| `Date` | : [`DATE`](sig/DATE.md) |  | required |  | [lib/basis/date.sml](../../../lib/basis/date.sml) |
| `FixedInt` | : [`INTEGER`](sig/INTEGER.md) |  | optional | is `Int` | [lib/basis/int64.sml](../../../lib/basis/int64.sml) |
| `General` | : [`GENERAL`](sig/GENERAL.md) |  | required |  | [lib/basis/general.sml](../../../lib/basis/general.sml) |
| `GenericSock` | : [`GENERIC_SOCK`](sig/GENERIC_SOCK.md) |  | optional | is `RuneGenericSock` | [lib/basis/inetsock.sml](../../../lib/basis/inetsock.sml) |
| `IEEEReal` | : [`IEEE_REAL`](sig/IEEE_REAL.md) |  | optional |  | [lib/basis/ieeereal.sml](../../../lib/basis/ieeereal.sml) |
| `INetSock` | : [`INET_SOCK`](sig/INET_SOCK.md) |  | optional | is `RuneINetSock` | [lib/basis/inetsock.sml](../../../lib/basis/inetsock.sml) |
| `IO` | : [`IO`](sig/IO.md) |  | required |  | [lib/basis/io.sml](../../../lib/basis/io.sml) |
| `Int` | : [`INTEGER`](sig/INTEGER.md) |  | required |  | [lib/basis/int.sml](../../../lib/basis/int.sml) |
| `Int16` | : [`INTEGER`](sig/INTEGER.md) |  | optional | an application of `RuneIntNFn` | [lib/basis/int16.sml](../../../lib/basis/int16.sml) |
| `Int16Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Int16Vector.vector where type elem = Int16.int` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_int16.sml](../../../lib/basis/mono_int16.sml) |
| `Int16Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Int16Vector.vector where type elem = Int16.int` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_int16.sml](../../../lib/basis/mono_int16.sml) |
| `Int16ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Int16Vector.vector where type vector_slice = Int16VectorSlice.slice where type array = Int16Array.array where type elem = Int16.int` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_int16.sml](../../../lib/basis/mono_int16.sml) |
| `Int16Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Int16.int` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_int16.sml](../../../lib/basis/mono_int16.sml) |
| `Int16VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Int16Vector.vector where type elem = Int16.int` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_int16.sml](../../../lib/basis/mono_int16.sml) |
| `Int32` | : [`INTEGER`](sig/INTEGER.md) |  | optional | an application of `RuneIntNFn` | [lib/basis/int32.sml](../../../lib/basis/int32.sml) |
| `Int32Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Int32Vector.vector where type elem = Int32.int` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_int32.sml](../../../lib/basis/mono_int32.sml) |
| `Int32Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Int32Vector.vector where type elem = Int32.int` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_int32.sml](../../../lib/basis/mono_int32.sml) |
| `Int32ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Int32Vector.vector where type vector_slice = Int32VectorSlice.slice where type array = Int32Array.array where type elem = Int32.int` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_int32.sml](../../../lib/basis/mono_int32.sml) |
| `Int32Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Int32.int` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_int32.sml](../../../lib/basis/mono_int32.sml) |
| `Int32VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Int32Vector.vector where type elem = Int32.int` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_int32.sml](../../../lib/basis/mono_int32.sml) |
| `Int64` | : [`INTEGER`](sig/INTEGER.md) |  | optional | is `Int` | [lib/basis/int64.sml](../../../lib/basis/int64.sml) |
| `Int64Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Int64Vector.vector where type elem = Int64.int` | optional | is `IntArray` | [lib/basis/mono\_int64.sml](../../../lib/basis/mono_int64.sml) |
| `Int64Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Int64Vector.vector where type elem = Int64.int` | optional | is `IntArray2` | [lib/basis/mono\_int64.sml](../../../lib/basis/mono_int64.sml) |
| `Int64ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Int64Vector.vector where type vector_slice = Int64VectorSlice.slice where type array = Int64Array.array where type elem = Int64.int` | optional | is `IntArraySlice` | [lib/basis/mono\_int64.sml](../../../lib/basis/mono_int64.sml) |
| `Int64Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Int64.int` | optional | is `IntVector` | [lib/basis/mono\_int64.sml](../../../lib/basis/mono_int64.sml) |
| `Int64VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Int64Vector.vector where type elem = Int64.int` | optional | is `IntVectorSlice` | [lib/basis/mono\_int64.sml](../../../lib/basis/mono_int64.sml) |
| `Int8` | : [`INTEGER`](sig/INTEGER.md) |  | optional | an application of `RuneIntNFn` | [lib/basis/int8.sml](../../../lib/basis/int8.sml) |
| `Int8Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Int8Vector.vector where type elem = Int8.int` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_int8.sml](../../../lib/basis/mono_int8.sml) |
| `Int8Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Int8Vector.vector where type elem = Int8.int` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_int8.sml](../../../lib/basis/mono_int8.sml) |
| `Int8ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Int8Vector.vector where type vector_slice = Int8VectorSlice.slice where type array = Int8Array.array where type elem = Int8.int` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_int8.sml](../../../lib/basis/mono_int8.sml) |
| `Int8Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Int8.int` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_int8.sml](../../../lib/basis/mono_int8.sml) |
| `Int8VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Int8Vector.vector where type elem = Int8.int` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_int8.sml](../../../lib/basis/mono_int8.sml) |
| `IntArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = IntVector.vector where type elem = int` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_int.sml](../../../lib/basis/mono_int.sml) |
| `IntArray2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = IntVector.vector where type elem = int` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_int.sml](../../../lib/basis/mono_int.sml) |
| `IntArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = IntVector.vector where type vector_slice = IntVectorSlice.slice where type array = IntArray.array where type elem = int` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_int.sml](../../../lib/basis/mono_int.sml) |
| `IntInf` | : [`INTEGER`](sig/INTEGER.md) |  | optional |  | [lib/basis/intinf.sml](../../../lib/basis/intinf.sml) |
| `IntInf` | : [`INT_INF`](sig/INT_INF.md) |  | optional |  | [lib/basis/intinf.sml](../../../lib/basis/intinf.sml) |
| `IntVector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = int` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_int.sml](../../../lib/basis/mono_int.sml) |
| `IntVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = IntVector.vector where type elem = int` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_int.sml](../../../lib/basis/mono_int.sml) |
| `LargeInt` | : [`INTEGER`](sig/INTEGER.md) |  | required | is `IntInf` | [lib/basis/intinf.sml](../../../lib/basis/intinf.sml) |
| `LargeIntArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = LargeIntVector.vector where type elem = LargeInt.int` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_largeint.sml](../../../lib/basis/mono_largeint.sml) |
| `LargeIntArray2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = LargeIntVector.vector where type elem = LargeInt.int` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_largeint.sml](../../../lib/basis/mono_largeint.sml) |
| `LargeIntArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = LargeIntVector.vector where type vector_slice = LargeIntVectorSlice.slice where type array = LargeIntArray.array where type elem = LargeInt.int` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_largeint.sml](../../../lib/basis/mono_largeint.sml) |
| `LargeIntVector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = LargeInt.int` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_largeint.sml](../../../lib/basis/mono_largeint.sml) |
| `LargeIntVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = LargeIntVector.vector where type elem = LargeInt.int` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_largeint.sml](../../../lib/basis/mono_largeint.sml) |
| `LargeReal` | : [`REAL`](sig/REAL.md) |  | required | is `Real` | [lib/basis/real.sml](../../../lib/basis/real.sml) |
| `LargeReal.Math` | : [`MATH`](sig/MATH.md) |  | required |  | [lib/basis/real.sml](../../../lib/basis/real.sml) |
| `LargeRealArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = LargeRealVector.vector where type elem = LargeReal.real` | optional | is `RealArray` | [lib/basis/mono\_largereal.sml](../../../lib/basis/mono_largereal.sml) |
| `LargeRealArray2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = LargeRealVector.vector where type elem = LargeReal.real` | optional | is `RealArray2` | [lib/basis/mono\_largereal.sml](../../../lib/basis/mono_largereal.sml) |
| `LargeRealArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = LargeRealVector.vector where type vector_slice = LargeRealVectorSlice.slice where type array = LargeRealArray.array where type elem = LargeReal.real` | optional | is `RealArraySlice` | [lib/basis/mono\_largereal.sml](../../../lib/basis/mono_largereal.sml) |
| `LargeRealVector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = LargeReal.real` | optional | is `RealVector` | [lib/basis/mono\_largereal.sml](../../../lib/basis/mono_largereal.sml) |
| `LargeRealVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = LargeRealVector.vector where type elem = LargeReal.real` | optional | is `RealVectorSlice` | [lib/basis/mono\_largereal.sml](../../../lib/basis/mono_largereal.sml) |
| `LargeWord` | : [`WORD`](sig/WORD.md) |  | required | is `Word` | [lib/basis/word.sml](../../../lib/basis/word.sml) |
| `LargeWordArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = LargeWordVector.vector where type elem = LargeWord.word` | optional | is `WordArray` | [lib/basis/mono\_largeword.sml](../../../lib/basis/mono_largeword.sml) |
| `LargeWordArray2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = LargeWordVector.vector where type elem = LargeWord.word` | optional | is `WordArray2` | [lib/basis/mono\_largeword.sml](../../../lib/basis/mono_largeword.sml) |
| `LargeWordArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = LargeWordVector.vector where type vector_slice = LargeWordVectorSlice.slice where type array = LargeWordArray.array where type elem = LargeWord.word` | optional | is `WordArraySlice` | [lib/basis/mono\_largeword.sml](../../../lib/basis/mono_largeword.sml) |
| `LargeWordVector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = LargeWord.word` | optional | is `WordVector` | [lib/basis/mono\_largeword.sml](../../../lib/basis/mono_largeword.sml) |
| `LargeWordVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = LargeWordVector.vector where type elem = LargeWord.word` | optional | is `WordVectorSlice` | [lib/basis/mono\_largeword.sml](../../../lib/basis/mono_largeword.sml) |
| `List` | : [`LIST`](sig/LIST.md) |  | required |  | [lib/basis/list.sml](../../../lib/basis/list.sml) |
| `ListPair` | : [`LIST_PAIR`](sig/LIST_PAIR.md) |  | required |  | [lib/basis/listpair.sml](../../../lib/basis/listpair.sml) |
| `Math` | : [`MATH`](sig/MATH.md) | `where type real = Real.real` | required | is `Real.Math` | [lib/basis/real.sml](../../../lib/basis/real.sml) |
| `NetHostDB` | : [`NET_HOST_DB`](sig/NET_HOST_DB.md) |  | optional | is `RuneNetHostDB` | [lib/basis/netdb.sml](../../../lib/basis/netdb.sml) |
| `NetProtDB` | : [`NET_PROT_DB`](sig/NET_PROT_DB.md) |  | optional | is `RuneNetProtDB` | [lib/basis/netdb.sml](../../../lib/basis/netdb.sml) |
| `NetServDB` | : [`NET_SERV_DB`](sig/NET_SERV_DB.md) |  | optional | is `RuneNetServDB` | [lib/basis/netdb.sml](../../../lib/basis/netdb.sml) |
| `OS` | : [`OS`](sig/OS.md) |  | required |  | [lib/basis/os.sml](../../../lib/basis/os.sml) |
| `OS.FileSys` | : [`OS_FILE_SYS`](sig/OS_FILE_SYS.md) |  | required | is `RuneFileSys` | [lib/basis/os.sml](../../../lib/basis/os.sml) |
| `OS.IO` | : [`OS_IO`](sig/OS_IO.md) |  | required | is `RuneIODesc` | [lib/basis/os.sml](../../../lib/basis/os.sml) |
| `OS.Path` | : [`OS_PATH`](sig/OS_PATH.md) |  | required | is `RunePath` | [lib/basis/os.sml](../../../lib/basis/os.sml) |
| `OS.Process` | : [`OS_PROCESS`](sig/OS_PROCESS.md) |  | required |  | [lib/basis/os.sml](../../../lib/basis/os.sml) |
| `Option` | : [`OPTION`](sig/OPTION.md) |  | required |  | [lib/basis/option.sml](../../../lib/basis/option.sml) |
| `PackReal32Big` | : [`PACK_REAL`](sig/PACK_REAL.md) | `where type real = Real32.real` | optional | an application of `RunePackReal32Fn` | [lib/basis/pack\_real32.sml](../../../lib/basis/pack_real32.sml) |
| `PackReal32Little` | : [`PACK_REAL`](sig/PACK_REAL.md) | `where type real = Real32.real` | optional | an application of `RunePackReal32Fn` | [lib/basis/pack\_real32.sml](../../../lib/basis/pack_real32.sml) |
| `PackReal64Big` | : [`PACK_REAL`](sig/PACK_REAL.md) | `where type real = Real64.real` | optional | is `PackRealBig` | [lib/basis/pack\_real.sml](../../../lib/basis/pack_real.sml) |
| `PackReal64Little` | : [`PACK_REAL`](sig/PACK_REAL.md) | `where type real = Real64.real` | optional | is `PackRealLittle` | [lib/basis/pack\_real.sml](../../../lib/basis/pack_real.sml) |
| `PackRealBig` | : [`PACK_REAL`](sig/PACK_REAL.md) | `where type real = Real.real` | optional | an application of `RunePackRealFn` | [lib/basis/pack\_real.sml](../../../lib/basis/pack_real.sml) |
| `PackRealLittle` | : [`PACK_REAL`](sig/PACK_REAL.md) | `where type real = Real.real` | optional | an application of `RunePackRealFn` | [lib/basis/pack\_real.sml](../../../lib/basis/pack_real.sml) |
| `PackWord16Big` | : [`PACK_WORD`](sig/PACK_WORD.md) |  | optional | an application of `RunePackWordFn` | [lib/basis/pack\_word.sml](../../../lib/basis/pack_word.sml) |
| `PackWord16Little` | : [`PACK_WORD`](sig/PACK_WORD.md) |  | optional | an application of `RunePackWordFn` | [lib/basis/pack\_word.sml](../../../lib/basis/pack_word.sml) |
| `PackWord32Big` | : [`PACK_WORD`](sig/PACK_WORD.md) |  | optional | an application of `RunePackWordFn` | [lib/basis/pack\_word.sml](../../../lib/basis/pack_word.sml) |
| `PackWord32Little` | : [`PACK_WORD`](sig/PACK_WORD.md) |  | optional | an application of `RunePackWordFn` | [lib/basis/pack\_word.sml](../../../lib/basis/pack_word.sml) |
| `PackWord64Big` | : [`PACK_WORD`](sig/PACK_WORD.md) |  | optional | an application of `RunePackWordFn` | [lib/basis/pack\_word.sml](../../../lib/basis/pack_word.sml) |
| `PackWord64Little` | : [`PACK_WORD`](sig/PACK_WORD.md) |  | optional | an application of `RunePackWordFn` | [lib/basis/pack\_word.sml](../../../lib/basis/pack_word.sml) |
| `Position` | : [`INTEGER`](sig/INTEGER.md) |  | required | is `Int` | [lib/basis/position.sml](../../../lib/basis/position.sml) |
| `Posix` | : [`POSIX`](sig/POSIX.md) | `where type FileSys.dirstream = OS.FileSys.dirstream where type FileSys.access_mode = OS.FileSys.access_mode` | optional |  | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.Error` | : [`POSIX_ERROR`](sig/POSIX_ERROR.md) |  | optional | is `RunePosixError` | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.FileSys` | : [`POSIX_FILE_SYS`](sig/POSIX_FILE_SYS.md) |  | optional | is `RunePosixFileSys` | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.FileSys.O` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_filesys.sml](../../../lib/basis/posix_filesys.sml) |
| `Posix.FileSys.S` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_filesys.sml](../../../lib/basis/posix_filesys.sml) |
| `Posix.IO` | : [`POSIX_IO`](sig/POSIX_IO.md) |  | optional | is `RunePosixIO` | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.IO.FD` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_io.sml](../../../lib/basis/posix_io.sml) |
| `Posix.IO.O` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_io.sml](../../../lib/basis/posix_io.sml) |
| `Posix.ProcEnv` | : [`POSIX_PROC_ENV`](sig/POSIX_PROC_ENV.md) |  | optional | is `RunePosixProcEnv` | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.Process` | : [`POSIX_PROCESS`](sig/POSIX_PROCESS.md) |  | optional | is `RunePosixProcess` | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.Process.W` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_process.sml](../../../lib/basis/posix_process.sml) |
| `Posix.Signal` | : [`POSIX_SIGNAL`](sig/POSIX_SIGNAL.md) |  | optional | is `RunePosixSignal` | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.SysDB` | : [`POSIX_SYS_DB`](sig/POSIX_SYS_DB.md) |  | optional | is `RunePosixSysDB` | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.TTY` | : [`POSIX_TTY`](sig/POSIX_TTY.md) |  | optional | is `RunePosixTTY` | [lib/basis/posix.sml](../../../lib/basis/posix.sml) |
| `Posix.TTY.C` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_tty.sml](../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.I` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_tty.sml](../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.L` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_tty.sml](../../../lib/basis/posix_tty.sml) |
| `Posix.TTY.O` | : [`BIT_FLAGS`](sig/BIT_FLAGS.md) |  | optional |  | [lib/basis/posix\_tty.sml](../../../lib/basis/posix_tty.sml) |
| `Real` | : [`REAL`](sig/REAL.md) | `where type real = real` | required |  | [lib/basis/real.sml](../../../lib/basis/real.sml) |
| `Real.Math` | : [`MATH`](sig/MATH.md) |  | required |  | [lib/basis/real.sml](../../../lib/basis/real.sml) |
| `Real32` | :> [`REAL`](sig/REAL.md) |  | optional | is `RuneReal32` | [lib/basis/real32.sml](../../../lib/basis/real32.sml) |
| `Real32Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Real32Vector.vector where type elem = Real32.real` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_real32.sml](../../../lib/basis/mono_real32.sml) |
| `Real32Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Real32Vector.vector where type elem = Real32.real` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_real32.sml](../../../lib/basis/mono_real32.sml) |
| `Real32ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Real32Vector.vector where type vector_slice = Real32VectorSlice.slice where type array = Real32Array.array where type elem = Real32.real` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_real32.sml](../../../lib/basis/mono_real32.sml) |
| `Real32Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Real32.real` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_real32.sml](../../../lib/basis/mono_real32.sml) |
| `Real32VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Real32Vector.vector where type elem = Real32.real` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_real32.sml](../../../lib/basis/mono_real32.sml) |
| `Real64` | : [`REAL`](sig/REAL.md) |  | optional | is `Real` | [lib/basis/real.sml](../../../lib/basis/real.sml) |
| `Real64.Math` | : [`MATH`](sig/MATH.md) |  | required |  | [lib/basis/real.sml](../../../lib/basis/real.sml) |
| `Real64Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Real64Vector.vector where type elem = Real64.real` | optional | is `RealArray` | [lib/basis/mono\_real64.sml](../../../lib/basis/mono_real64.sml) |
| `Real64Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Real64Vector.vector where type elem = Real64.real` | optional | is `RealArray2` | [lib/basis/mono\_real64.sml](../../../lib/basis/mono_real64.sml) |
| `Real64ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Real64Vector.vector where type vector_slice = Real64VectorSlice.slice where type array = Real64Array.array where type elem = Real64.real` | optional | is `RealArraySlice` | [lib/basis/mono\_real64.sml](../../../lib/basis/mono_real64.sml) |
| `Real64Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Real64.real` | optional | is `RealVector` | [lib/basis/mono\_real64.sml](../../../lib/basis/mono_real64.sml) |
| `Real64VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Real64Vector.vector where type elem = Real64.real` | optional | is `RealVectorSlice` | [lib/basis/mono\_real64.sml](../../../lib/basis/mono_real64.sml) |
| `RealArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = RealVector.vector where type elem = real` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_real.sml](../../../lib/basis/mono_real.sml) |
| `RealArray2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = RealVector.vector where type elem = real` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_real.sml](../../../lib/basis/mono_real.sml) |
| `RealArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = RealVector.vector where type vector_slice = RealVectorSlice.slice where type array = RealArray.array where type elem = real` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_real.sml](../../../lib/basis/mono_real.sml) |
| `RealVector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = real` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_real.sml](../../../lib/basis/mono_real.sml) |
| `RealVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = RealVector.vector where type elem = real` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_real.sml](../../../lib/basis/mono_real.sml) |
| `SML90` | : [`SML90`](sig/SML90.md) |  | optional |  | [lib/basis/sml90.sml](../../../lib/basis/sml90.sml) |
| `Socket` | : [`SOCKET`](sig/SOCKET.md) |  | optional | is `RuneSocket` | [lib/basis/socket.sml](../../../lib/basis/socket.sml) |
| `String` | : [`STRING`](sig/STRING.md) | `where type string = string where type char = Char.char` | required |  | [lib/basis/string.sml](../../../lib/basis/string.sml) |
| `StringCvt` | : [`STRING_CVT`](sig/STRING_CVT.md) |  | required |  | [lib/basis/stringcvt.sml](../../../lib/basis/stringcvt.sml) |
| `Substring` | : [`SUBSTRING`](sig/SUBSTRING.md) | `where type string = string where type char = Char.char` | required |  | [lib/basis/substring.sml](../../../lib/basis/substring.sml) |
| `SysWord` | : [`WORD`](sig/WORD.md) |  | optional | is `Word` | [lib/basis/word.sml](../../../lib/basis/word.sml) |
| `Text` | : [`TEXT`](sig/TEXT.md) | `where type Char.char = Char.char where type String.string = String.string where type Substring.substring = Substring.substring where type CharArray.array = CharArray.array where type CharVectorSlice.slice = CharVectorSlice.slice where type CharArraySlice.slice = CharArraySlice.slice` | required |  | [lib/basis/text.sml](../../../lib/basis/text.sml) |
| `TextIO` | : [`IMPERATIVE_IO`](sig/IMPERATIVE_IO.md) |  | required |  | [lib/basis/textio.sml](../../../lib/basis/textio.sml) |
| `TextIO` | : [`TEXT_IO`](sig/TEXT_IO.md) |  | required |  | [lib/basis/textio.sml](../../../lib/basis/textio.sml) |
| `TextIO.StreamIO` | : [`STREAM_IO`](sig/STREAM_IO.md) |  | required |  | [lib/basis/textio.sml](../../../lib/basis/textio.sml) |
| `TextIO.StreamIO` | : [`TEXT_STREAM_IO`](sig/TEXT_STREAM_IO.md) | `where type reader = TextPrimIO.reader where type writer = TextPrimIO.writer where type pos = TextPrimIO.pos` | required |  | [lib/basis/textio.sml](../../../lib/basis/textio.sml) |
| `TextPrimIO` | : [`PRIM_IO`](sig/PRIM_IO.md) | `where type array = CharArray.array where type vector = CharVector.vector where type elem = Char.char where type vector_slice = CharVectorSlice.slice where type array_slice = CharArraySlice.slice` | required | an application of `RunePrimIOFn` | [lib/basis/textprimio.sml](../../../lib/basis/textprimio.sml) |
| `Time` | :> [`TIME`](sig/TIME.md) |  | required |  | [lib/basis/time.sml](../../../lib/basis/time.sml) |
| `Timer` | : [`TIMER`](sig/TIMER.md) |  | required |  | [lib/basis/timer.sml](../../../lib/basis/timer.sml) |
| `Unix` | : [`UNIX`](sig/UNIX.md) | `where type exit_status = Posix.Process.exit_status where type signal = Posix.Signal.signal` | optional |  | [lib/basis/unix.sml](../../../lib/basis/unix.sml) |
| `UnixSock` | : [`UNIX_SOCK`](sig/UNIX_SOCK.md) |  | optional | is `RuneUnixSock` | [lib/basis/inetsock.sml](../../../lib/basis/inetsock.sml) |
| `Vector` | : [`VECTOR`](sig/VECTOR.md) |  | required |  | [lib/basis/vector.sml](../../../lib/basis/vector.sml) |
| `VectorSlice` | : [`VECTOR_SLICE`](sig/VECTOR_SLICE.md) |  | required |  | [lib/basis/vectorslice.sml](../../../lib/basis/vectorslice.sml) |
| `WideChar` | :> [`CHAR`](sig/CHAR.md) | `where type char = WideChar.char where type string = WideString.string` | optional | is `RuneWideCharImpl` | [lib/basis/widechar.sml](../../../lib/basis/widechar.sml) |
| `WideCharArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = WideCharVector.vector where type elem = WideChar.char` | optional | an application of `RuneMonoArrayFn` | [lib/basis/widechar.sml](../../../lib/basis/widechar.sml) |
| `WideCharArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = WideCharVector.vector where type vector_slice = WideCharVectorSlice.slice where type array = WideCharArray.array where type elem = WideChar.char` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/widechar.sml](../../../lib/basis/widechar.sml) |
| `WideCharVector` | :> [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = WideChar.char` | optional | an application of `RuneMonoVectorFn` | [lib/basis/widechar.sml](../../../lib/basis/widechar.sml) |
| `WideCharVector` | :> [`MONO_VECTOR_EQ`](sig/MONO_VECTOR_EQ.md) | `where type elem = RuneWideChar.char` | optional | an application of `RuneMonoVectorFn` | [lib/basis/widechar.sml](../../../lib/basis/widechar.sml) |
| `WideCharVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = WideCharVector.vector where type elem = WideChar.char` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/widechar.sml](../../../lib/basis/widechar.sml) |
| `WideString` | :> [`STRING`](sig/STRING.md) | `where type string = WideCharVector.vector where type char = WideChar.char` | optional | is `RuneWideString` | [lib/basis/widestring.sml](../../../lib/basis/widestring.sml) |
| `WideSubstring` | :> [`SUBSTRING`](sig/SUBSTRING.md) | `where type substring = WideCharVectorSlice.slice where type string = WideCharVector.vector where type char = WideChar.char` | optional | is `RuneWideSubstring` | [lib/basis/widestring.sml](../../../lib/basis/widestring.sml) |
| `WideText` | : [`TEXT`](sig/TEXT.md) |  | optional |  | [lib/basis/widetext.sml](../../../lib/basis/widetext.sml) |
| `WideTextPrimIO` | : [`PRIM_IO`](sig/PRIM_IO.md) | `where type array = WideCharArray.array where type vector = WideCharVector.vector where type elem = WideChar.char where type vector_slice = WideCharVectorSlice.slice where type array_slice = WideCharArraySlice.slice` | optional | an application of `RunePrimIOFn` | [lib/basis/widetextio.sml](../../../lib/basis/widetextio.sml) |
| `Word` | : [`WORD`](sig/WORD.md) |  | required |  | [lib/basis/word.sml](../../../lib/basis/word.sml) |
| `Word16` | : [`WORD`](sig/WORD.md) |  | optional | an application of `RuneWordNFn` | [lib/basis/word16.sml](../../../lib/basis/word16.sml) |
| `Word16Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Word16Vector.vector where type elem = Word16.word` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_word16.sml](../../../lib/basis/mono_word16.sml) |
| `Word16Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Word16Vector.vector where type elem = Word16.word` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_word16.sml](../../../lib/basis/mono_word16.sml) |
| `Word16ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Word16Vector.vector where type vector_slice = Word16VectorSlice.slice where type array = Word16Array.array where type elem = Word16.word` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_word16.sml](../../../lib/basis/mono_word16.sml) |
| `Word16Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Word16.word` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_word16.sml](../../../lib/basis/mono_word16.sml) |
| `Word16VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Word16Vector.vector where type elem = Word16.word` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_word16.sml](../../../lib/basis/mono_word16.sml) |
| `Word32` | : [`WORD`](sig/WORD.md) |  | optional | an application of `RuneWordNFn` | [lib/basis/word32.sml](../../../lib/basis/word32.sml) |
| `Word32Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Word32Vector.vector where type elem = Word32.word` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_word32.sml](../../../lib/basis/mono_word32.sml) |
| `Word32Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Word32Vector.vector where type elem = Word32.word` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_word32.sml](../../../lib/basis/mono_word32.sml) |
| `Word32ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Word32Vector.vector where type vector_slice = Word32VectorSlice.slice where type array = Word32Array.array where type elem = Word32.word` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_word32.sml](../../../lib/basis/mono_word32.sml) |
| `Word32Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Word32.word` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_word32.sml](../../../lib/basis/mono_word32.sml) |
| `Word32VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Word32Vector.vector where type elem = Word32.word` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_word32.sml](../../../lib/basis/mono_word32.sml) |
| `Word64` | : [`WORD`](sig/WORD.md) |  | optional | is `Word` | [lib/basis/word64.sml](../../../lib/basis/word64.sml) |
| `Word64Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Word64Vector.vector where type elem = Word64.word` | optional | is `WordArray` | [lib/basis/mono\_word64.sml](../../../lib/basis/mono_word64.sml) |
| `Word64Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Word64Vector.vector where type elem = Word64.word` | optional | is `WordArray2` | [lib/basis/mono\_word64.sml](../../../lib/basis/mono_word64.sml) |
| `Word64ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Word64Vector.vector where type vector_slice = Word64VectorSlice.slice where type array = Word64Array.array where type elem = Word64.word` | optional | is `WordArraySlice` | [lib/basis/mono\_word64.sml](../../../lib/basis/mono_word64.sml) |
| `Word64Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Word64.word` | optional | is `WordVector` | [lib/basis/mono\_word64.sml](../../../lib/basis/mono_word64.sml) |
| `Word64VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Word64Vector.vector where type elem = Word64.word` | optional | is `WordVectorSlice` | [lib/basis/mono\_word64.sml](../../../lib/basis/mono_word64.sml) |
| `Word8` | : [`WORD`](sig/WORD.md) |  | required | an application of `RuneWordNFn` | [lib/basis/word8.sml](../../../lib/basis/word8.sml) |
| `Word8Array` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = Word8Vector.vector where type elem = Word8.word` | required | an application of `RuneMonoArrayFn` | [lib/basis/word8array.sml](../../../lib/basis/word8array.sml) |
| `Word8Array2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = Word8Vector.vector where type elem = Word8.word` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/word8array2.sml](../../../lib/basis/word8array2.sml) |
| `Word8ArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = Word8Vector.vector where type vector_slice = Word8VectorSlice.slice where type array = Word8Array.array where type elem = Word8.word` | required | an application of `RuneMonoArraySliceFn` | [lib/basis/word8arrayslice.sml](../../../lib/basis/word8arrayslice.sml) |
| `Word8Vector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = Word8.word` | required | an application of `RuneStringVectorFn` | [lib/basis/word8vector.sml](../../../lib/basis/word8vector.sml) |
| `Word8VectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = Word8Vector.vector where type elem = Word8.word` | required |  | [lib/basis/word8vectorslice.sml](../../../lib/basis/word8vectorslice.sml) |
| `WordArray` | : [`MONO_ARRAY`](sig/MONO_ARRAY.md) | `where type vector = WordVector.vector where type elem = word` | optional | an application of `RuneMonoArrayFn` | [lib/basis/mono\_word.sml](../../../lib/basis/mono_word.sml) |
| `WordArray2` | : [`MONO_ARRAY2`](sig/MONO_ARRAY2.md) | `where type vector = WordVector.vector where type elem = word` | optional | an application of `RuneMonoArray2Fn` | [lib/basis/mono\_word.sml](../../../lib/basis/mono_word.sml) |
| `WordArraySlice` | : [`MONO_ARRAY_SLICE`](sig/MONO_ARRAY_SLICE.md) | `where type vector = WordVector.vector where type vector_slice = WordVectorSlice.slice where type array = WordArray.array where type elem = word` | optional | an application of `RuneMonoArraySliceFn` | [lib/basis/mono\_word.sml](../../../lib/basis/mono_word.sml) |
| `WordVector` | : [`MONO_VECTOR`](sig/MONO_VECTOR.md) | `where type elem = word` | optional | an application of `RuneMonoVectorFn` | [lib/basis/mono\_word.sml](../../../lib/basis/mono_word.sml) |
| `WordVectorSlice` | : [`MONO_VECTOR_SLICE`](sig/MONO_VECTOR_SLICE.md) | `where type vector = WordVector.vector where type elem = word` | optional | an application of `RuneMonoVectorSliceFn` | [lib/basis/mono\_word.sml](../../../lib/basis/mono_word.sml) |

---

<sub>Generated by runedoc; do not edit.</sub>
