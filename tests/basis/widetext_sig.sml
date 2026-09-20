(* requires: WideText WideChar WideString WideSubstring WideCharVector WideCharArray WideCharVectorSlice WideCharArraySlice *)
(* uses: spec-sigs/CHAR.sml spec-sigs/STRING.sml spec-sigs/SUBSTRING.sml spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml spec-sigs/MONO_VECTOR_SLICE.sml spec-sigs/MONO_ARRAY_SLICE.sml spec-sigs/TEXT.sml *)
(* WideText matches TEXT, and its structures are those of the wide character,
   as Text's are those of char (tests/basis/text_sig.sml explains why the
   constraint on CharVector.vector is checked on values). *)
structure TestWideTextSig =
struct
  structure C : SPEC_TEXT = WideText
  val () = T.check ("WideText:TEXT/matches", fn () => true)
  structure W : SPEC_TEXT
    where type Char.char = WideChar.char
    where type String.string = WideString.string
    where type Substring.substring = WideSubstring.substring
    where type CharArray.array = WideCharArray.array
    where type CharVectorSlice.slice = WideCharVectorSlice.slice
    where type CharArraySlice.slice = WideCharArraySlice.slice = WideText
  val () = T.check ("WideText:TEXT/where-types", fn () => true)
  val () = T.check ("WideText:TEXT/Char.char", fn () => W.Char.ord (WideChar.chr 65) = 65
                                                          andalso WideChar.ord (W.Char.chr 0x1F600) = 0x1F600)
  val () = T.check ("WideText:TEXT/String.string",
                    fn () => W.String.size (WideString.implode [WideChar.chr 97, WideChar.chr 0x100]) = 2
                             andalso WideString.size (W.String.implode [WideChar.chr 97]) = 1)
  val () = T.check ("WideText:TEXT/Substring.substring",
                    fn () => W.Substring.size (WideSubstring.full (WideString.str (WideChar.chr 97))) = 1)
  val () = T.check ("WideText:TEXT/CharVector.vector",
                    fn () => WideCharVector.length (W.String.implode [WideChar.chr 97]) = 1
                             andalso W.CharVector.length (WideCharVector.fromList [WideChar.chr 97]) = 1)
  val () = T.check ("WideText:TEXT/CharArray.array",
                    fn () => WideCharArray.length (W.CharArray.array (2, WideChar.chr 97)) = 2)
  val () = T.check ("WideText:TEXT/CharVectorSlice.slice",
                    fn () => WideCharVectorSlice.length (W.CharVectorSlice.full (WideString.str (WideChar.chr 97))) = 1)
  val () = T.check ("WideText:TEXT/CharArraySlice.slice",
                    fn () => WideCharArraySlice.length (W.CharArraySlice.full (WideCharArray.array (3, WideChar.chr 97))) = 3)
end
