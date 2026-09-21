(* Implements: MONO_ARRAY_SLICE where type vector = Word8Vector.vector where
   type vector_slice = Word8VectorSlice.slice where type array =
   Word8Array.array where type elem = Word8.word *)
structure Word8ArraySlice :> MONO_ARRAY_SLICE where type vector = Word8Vector.vector where type vector_slice = Word8VectorSlice.slice where type array = Word8Array.array where type elem = Word8.word = RuneMonoArraySliceFn (structure V = Word8Vector structure A = Word8Array structure VS = Word8VectorSlice)
