(* requires: Substring *)
(* uses: spec-sigs/SUBSTRING.sml *)
(* Substring matches SUBSTRING, `where type substring = CharVectorSlice.slice
   where type string = String.string where type char = Char.char`. *)
structure TestSubstringSig =
struct
  structure C : SPEC_SUBSTRING where type string = string where type char = Char.char = Substring
  val () = T.check ("Substring:SUBSTRING/matches", fn () => true)
  val () = T.check ("Substring:SUBSTRING/string-is-toplevel", fn () => size (C.string (C.full "abc") : string) = 3)
  val () = T.check ("Substring:SUBSTRING/toplevel-is-string", fn () => C.size (C.full ("ab" ^ "c" : C.string)) = 3)
  val () = T.check ("Substring:SUBSTRING/string-is-String.string",
                    fn () => String.size (C.string (C.full "abc")) = 3 andalso #1 (C.base (C.full (String.str #"x"))) = "x")
  val () = T.check ("Substring:SUBSTRING/char-is-Char.char", fn () => Char.ord (C.sub (C.full "abc", 1) : C.char) = 98)
  val () = T.check ("Substring:SUBSTRING/char-is-toplevel", fn () => C.first (C.full (str (#"a" : char))) = SOME #"a")
  val () = T.check ("Substring:SUBSTRING/substring-is-Substring.substring",
                    fn () => Substring.size (C.full "abc" : Substring.substring) = 3
                             andalso C.size (Substring.full "ab" : C.substring) = 2)
  (*<< CharVectorSlice *)
  structure V : SPEC_SUBSTRING where type substring = CharVectorSlice.slice = Substring
  val () = T.check ("Substring:SUBSTRING/substring-is-CharVectorSlice.slice",
                    fn () => CharVectorSlice.length (V.full "abc") = 3 andalso V.size (CharVectorSlice.full "ab") = 2)
  (*>> CharVectorSlice *)
  (* the signature can be implemented opaquely, given string and char *)
  structure O :> SPEC_SUBSTRING where type string = string where type char = char = Substring
  val () = T.check ("Substring:SUBSTRING/opaque-substring",
                    fn () => O.base (O.triml 1 (O.full "abc")) = ("abc", 1, 2) andalso O.string (O.full "xy") = "xy")
end
