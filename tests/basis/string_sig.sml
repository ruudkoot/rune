(* requires: String StringCvt *)
(* uses: spec-sigs/STRING.sml *)
(* String matches STRING, `where type string = string where type string =
   CharVector.vector where type char = Char.char`. *)
structure TestStringSig =
struct
  structure S : SPEC_STRING where type string = string where type char = Char.char = String
  val () = T.check ("String:STRING/matches", fn () => true)
  val () = T.check ("String:STRING/string-is-toplevel", fn () => size (S.^ ("ab", "c") : string) = 3)
  val () = T.check ("String:STRING/toplevel-is-string", fn () => S.size ("ab" ^ "c" : S.string) = 3)
  val () = T.check ("String:STRING/char-is-Char.char", fn () => Char.ord (S.sub ("abc", 1) : S.char) = 98)
  val () = T.check ("String:STRING/char-is-toplevel", fn () => S.str (#"a" : char) = "a")
  (*<< charvector *)
  structure V : SPEC_STRING where type string = CharVector.vector = String
  val () = T.check ("String:STRING/string-is-CharVector.vector",
                    fn () => CharVector.length (V.^ ("ab", "c")) = 3 andalso V.size (CharVector.fromList [#"a"]) = 1)
  (*>> charvector *)
end
