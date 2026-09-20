(* CharVector: CharVector.vector is string. *)
structure CharVector : MONO_VECTOR =
  RuneStringVectorFn (type elem = char
                      fun toChar c = c
                      fun fromChar c = c)
