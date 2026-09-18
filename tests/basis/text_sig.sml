(* requires: Text Char String Substring CharVector CharArray CharVectorSlice CharArraySlice StringCvt *)
(* uses: spec-sigs/CHAR.sml spec-sigs/STRING.sml spec-sigs/SUBSTRING.sml spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/TEXT.sml *)
(* Text matches TEXT, `where type Char.char = Char.char where type
   String.string = String.string where type Substring.substring =
   Substring.substring where type CharVector.vector = CharVector.vector where
   type CharArray.array = CharArray.array where type CharVectorSlice.slice =
   CharVectorSlice.slice where type CharArraySlice.slice =
   CharArraySlice.slice`.

   The constraint `where type CharVector.vector = CharVector.vector` of the
   page cannot be written after that of String.string: the signature shares
   the two types, so that the first constraint defines both and the second
   one names a type that is no longer flexible (Definition, rule 64). The
   check Text:TEXT/CharVector.vector shows the identity on values instead. *)
structure TestTextSig =
struct
  structure C : SPEC_TEXT = Text
  val () = T.check ("Text:TEXT/matches", fn () => true)
  structure W : SPEC_TEXT where type Char.char = Char.char where type String.string = String.string where type Substring.substring = Substring.substring where type CharArray.array = CharArray.array where type CharVectorSlice.slice = CharVectorSlice.slice where type CharArraySlice.slice = CharArraySlice.slice = Text
  val () = T.check ("Text:TEXT/where-types", fn () => true)
  val () = T.check ("Text:TEXT/Char.char", fn () => W.Char.ord (Char.chr 65) = 65 andalso Char.ord (W.Char.chr 66) = 66)
  val () = T.check ("Text:TEXT/String.string", fn () => W.String.size (String.implode [#"a", #"b"]) = 2
                                                         andalso String.size (W.String.implode [#"a"]) = 1)
  val () = T.check ("Text:TEXT/Substring.substring", fn () => W.Substring.size (Substring.full "abc") = 3
                                                               andalso Substring.size (W.Substring.full "ab") = 2)
  val () = T.check ("Text:TEXT/CharVector.vector", fn () => W.CharVector.length (CharVector.fromList [#"a"]) = 1
                                                             andalso CharVector.length (W.CharVector.fromList []) = 0)
  val () = T.check ("Text:TEXT/CharArray.array", fn () => W.CharArray.length (CharArray.array (2, #"a")) = 2
                                                           andalso CharArray.length (W.CharArray.array (3, #"a")) = 3)
  val () = T.check ("Text:TEXT/CharVectorSlice.slice", fn () => W.CharVectorSlice.length (CharVectorSlice.full "abc") = 3
                                                                 andalso CharVectorSlice.length (W.CharVectorSlice.full "ab") = 2)
  val () = T.check ("Text:TEXT/CharArraySlice.slice",
                    fn () => W.CharArraySlice.length (CharArraySlice.full (CharArray.array (2, #"a"))) = 2
                             andalso CharArraySlice.length (W.CharArraySlice.full (W.CharArray.array (3, #"a"))) = 3)
  (* the sharing of the signature: one char, one string, one array and one
     vector slice type *)
  val () = T.check ("Text:TEXT/sharing-char",
                    fn () => C.CharVector.sub (C.String.str (C.Char.chr 97), 0) = C.CharArray.sub (C.CharArray.array (1, valOf (C.Substring.first (C.Substring.full (C.Char.toString (C.Char.chr 97))))), 0))
  val () = T.check ("Text:TEXT/sharing-string",
                    fn () => C.String.size (C.CharVectorSlice.vector (C.CharVectorSlice.full (C.CharArraySlice.vector (C.CharArraySlice.full (C.CharArray.fromList (C.String.explode (C.Substring.string (C.Substring.full (C.Char.toString (C.Char.chr 97)))))))))) = 1)
  val () = T.check ("Text:TEXT/sharing-array",
                    fn () => C.CharArraySlice.length (C.CharArraySlice.full (C.CharArray.array (2, C.Char.chr 97))) = 2)
  val () = T.check ("Text:TEXT/sharing-vector_slice",
                    fn () => let val a = C.CharArray.array (3, C.Char.chr 45)
                             in C.CharArraySlice.copyVec {src = C.CharVectorSlice.full (C.CharVector.fromList [C.Char.chr 97]), dst = a, di = 1};
                                C.Char.ord (C.CharArray.sub (a, 1)) = 97 end)
end
