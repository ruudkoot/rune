(* CharArray: mutable arrays of characters, a type of their own with
   identity equality. Their vectors are strings: `vector` gives a `string`,
   and `copyVec` copies one in.

   Implements: MONO_ARRAY where type vector = CharVector.vector where type
   elem = char *)
structure CharArray :> MONO_ARRAY where type vector = CharVector.vector where type elem = char = RuneMonoArrayFn (structure V = CharVector)
