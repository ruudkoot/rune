(* Implements: MONO_ARRAY where type vector = Word8Vector.vector where type
   elem = Word8.word *)
structure Word8Array :> MONO_ARRAY where type vector = Word8Vector.vector where type elem = Word8.word = RuneMonoArrayFn (structure V = Word8Vector)
