(* CharVector: CharVector.vector is string.

   Implements: MONO_VECTOR where type vector = String.string where type elem =
   char *)
structure CharVector : MONO_VECTOR =
  RuneStringVectorFn (type elem = char
                      fun toChar c = c
                      fun fromChar c = c)
