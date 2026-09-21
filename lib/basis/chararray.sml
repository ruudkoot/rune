(* Implements: MONO_ARRAY where type vector = CharVector.vector where type
   elem = char *)
structure CharArray :> MONO_ARRAY where type vector = CharVector.vector where type elem = char = RuneMonoArrayFn (structure V = CharVector)
