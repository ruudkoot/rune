(* What a program sees of the structures of mono_largereal.sml: the members that their
   signatures name. The library itself is compiled before this file and has
   the structures whole (docs/plans/docgen.md, the decisions of 2026-09-21). *)
structure LargeRealArray : MONO_ARRAY where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealArray
structure LargeRealArray2 : MONO_ARRAY2 where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealArray2
structure LargeRealArraySlice : MONO_ARRAY_SLICE where type vector = LargeRealVector.vector where type vector_slice = LargeRealVectorSlice.slice where type array = LargeRealArray.array where type elem = LargeReal.real = LargeRealArraySlice
structure LargeRealVector : MONO_VECTOR where type elem = LargeReal.real = LargeRealVector
structure LargeRealVectorSlice : MONO_VECTOR_SLICE where type vector = LargeRealVector.vector where type elem = LargeReal.real = LargeRealVectorSlice
