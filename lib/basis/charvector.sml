(* CharVector: the strings, seen as vectors of characters. `CharVector.vector`
   is `string`, as the specification requires, so the functions of `String`
   and of this structure apply to the same values: `CharVector.map` is a
   `String.map` by another name.

   Implements: MONO_VECTOR where type vector = String.string where type elem =
   char *)
structure CharVector : MONO_VECTOR =
  RuneStringVectorFn (type elem = char
                      fun toChar c = c
                      fun fromChar c = c)
