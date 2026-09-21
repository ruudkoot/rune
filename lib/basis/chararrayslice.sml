(* Implements: MONO_ARRAY_SLICE where type vector = CharVector.vector where
   type vector_slice = CharVectorSlice.slice where type array =
   CharArray.array where type elem = char *)
structure CharArraySlice :> MONO_ARRAY_SLICE where type vector = CharVector.vector where type vector_slice = CharVectorSlice.slice where type array = CharArray.array where type elem = char = RuneMonoArraySliceFn (structure V = CharVector structure A = CharArray structure VS = CharVectorSlice)
