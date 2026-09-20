(* Word8Vector: a vector of bytes is a string.

   Implements: MONO_VECTOR where type elem = Word8.word

   Deviation: `Word8Vector.vector/is-string`. The specification gives
   `Word8Vector.vector` and `string` no relation, and a portable program goes
   from one to the other through `Byte`. Here they are one type, and the
   structure is not sealed, so a string constant is accepted where a vector
   of bytes is wanted; `BinIO.vector` and the vectors of `BinPrimIO` are
   strings with it. *)
structure Word8Vector : MONO_VECTOR =
  RuneStringVectorFn (type elem = Word8.word
                      fun toChar w = chr (Word8.toInt w)
                      fun fromChar c = Word8.fromInt (ord c))
