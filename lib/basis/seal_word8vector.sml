(* What a program sees of the byte vector and its slice: the members their
   signatures name, without the conversions to and from a string and a
   substring that the library crosses the boundary with. *)
structure Word8Vector : MONO_VECTOR where type elem = Word8.word = Word8Vector
structure Word8VectorSlice : MONO_VECTOR_SLICE
  where type vector = Word8Vector.vector where type elem = Word8.word = Word8VectorSlice
