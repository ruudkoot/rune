(* CharArraySlice: stretches of `CharArray` arrays, without a copy: an update
   through a slice changes the array. Its vector slices are substrings.

   Implements: MONO_ARRAY_SLICE where type vector = CharVector.vector where
   type vector_slice = CharVectorSlice.slice where type array =
   CharArray.array where type elem = char *)
structure CharArraySlice :> MONO_ARRAY_SLICE where type vector = CharVector.vector where type vector_slice = CharVectorSlice.slice where type array = CharArray.array where type elem = char = RuneMonoArraySliceFn (structure V = CharVector structure A = CharArray structure VS = CharVectorSlice)
