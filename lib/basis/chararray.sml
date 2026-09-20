(* Implements: MONO_ARRAY where type vector = CharVector.vector where type
   elem = char *)
structure CharArray : MONO_ARRAY = RuneMonoArrayFn (structure V = CharVector)
