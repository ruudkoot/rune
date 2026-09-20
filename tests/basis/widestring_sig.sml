(* requires: WideString WideChar WideCharVector *)
(* uses: spec-sigs/STRING.sml *)
(* WideString matches STRING, `where type string = WideCharVector.vector where
   type char = WideChar.char`, as String matches it with CharVector.vector and
   Char.char. *)
structure TestWideStringSig =
struct
  structure S : SPEC_STRING where type string = WideCharVector.vector where type char = WideChar.char = WideString
  val () = T.check ("WideString:STRING/matches", fn () => true)
  val () = T.check ("WideString:STRING/char-is-WideChar.char",
                    fn () => WideChar.ord (S.sub (S.str (WideChar.chr 97), 0) : WideChar.char) = 97)
  val () = T.check ("WideString:STRING/string-is-WideCharVector.vector",
                    fn () => WideCharVector.length (S.implode [WideChar.chr 97] : WideCharVector.vector) = 1)
  val () = T.check ("WideString:STRING/toString-gives-a-string-of-char",
                    fn () => size (S.toString (S.implode [WideChar.chr 0x100]) : string) = 6)
end
