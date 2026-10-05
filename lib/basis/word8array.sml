(* Word8Array: mutable arrays of bytes, a type of their own with identity
   equality, whose vectors are those of `Word8Vector`: the buffers of binary
   input and output. An array takes a byte an element and is laid out as C
   has an array of bytes; `vector`, `copy` and `copyVec` move the bytes in
   one step.

   Implements: MONO_ARRAY where type vector = Word8Vector.vector where type
   elem = Word8.word *)
structure Word8Array :> MONO_ARRAY where type vector = Word8Vector.vector where type elem = Word8.word =
  RuneByteArrayFn (structure V = Word8Vector
                   fun toChar w = chr (Word8.toInt w)
                   fun fromChar c = Word8.fromInt (ord c)
                   val vectorOf = Word8Vector.fromString
                   val stringOf = Word8Vector.toString)
