(* requires: WideChar WideString WideCharVector *)
(* uses: spec-sigs/CHAR.sml *)
(* WideChar matches CHAR, `where type char = WideChar.char where type string =
   WideString.string`, its string is the vector of WideCharVector, and its
   character set is that of Unicode. The text of toString and fromString is of
   char, the 8-bit one, as the signature writes it. *)
structure TestWideCharSig =
struct
  structure C : SPEC_CHAR where type char = WideChar.char where type string = WideString.string = WideChar
  val () = T.check ("WideChar:CHAR/matches", fn () => true)
  val () = T.check ("WideChar:CHAR/char-is-WideChar.char", fn () => WideChar.ord (C.chr 65 : WideChar.char) = 65)
  val () = T.check ("WideChar:CHAR/string-is-WideString.string",
                    fn () => WideString.size (WideString.str (C.chr 65) : C.string) = 1)
  val () = T.check ("WideChar:CHAR/string-is-WideCharVector.vector",
                    fn () => WideCharVector.length (WideCharVector.fromList [C.chr 65] : C.string) = 1)
  val () = T.check ("WideChar:CHAR/toString-gives-a-string-of-char",
                    fn () => size (C.toString (C.chr 0x100) : string) = 6)
  val () = T.check ("WideChar:CHAR/maxOrd-is-Unicode", fn () => C.maxOrd = 1114111)
end
