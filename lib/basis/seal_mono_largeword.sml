(* What a program sees of the structures of mono_largeword.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure LargeWordArray : MONO_ARRAY where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordArray
structure LargeWordArray2 : MONO_ARRAY2 where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordArray2
structure LargeWordArraySlice : MONO_ARRAY_SLICE where type vector = LargeWordVector.vector where type vector_slice = LargeWordVectorSlice.slice where type array = LargeWordArray.array where type elem = LargeWord.word = LargeWordArraySlice
structure LargeWordVector : MONO_VECTOR where type elem = LargeWord.word = LargeWordVector
structure LargeWordVectorSlice : MONO_VECTOR_SLICE where type vector = LargeWordVector.vector where type elem = LargeWord.word = LargeWordVectorSlice
