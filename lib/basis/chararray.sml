(* CharArray: mutable arrays of characters, a type of their own with
   identity equality. Their vectors are strings: `vector` gives a `string`,
   and `copyVec` copies one in. An array takes a byte a character.

   Implements: MONO_ARRAY where type vector = CharVector.vector where type
   elem = char *)
structure CharArray :> MONO_ARRAY where type vector = CharVector.vector where type elem = char =
  RuneByteArrayFn (structure V = CharVector
                   fun toChar c = c
                   fun fromChar c = c
                   fun vectorOf (s : string) = s
                   fun stringOf (s : string) = s)
