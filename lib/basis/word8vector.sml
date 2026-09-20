(* Word8Vector: a vector of bytes is a string.

   Implements: MONO_VECTOR where type elem = Word8.word *)
structure Word8Vector : MONO_VECTOR =
  RuneStringVectorFn (type elem = Word8.word
                      fun toChar w = chr (Word8.toInt w)
                      fun fromChar c = Word8.fromInt (ord c))
