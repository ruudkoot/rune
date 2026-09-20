(* requires: Char StringCvt *)
(* uses: spec-sigs/CHAR.sml *)
(* Char matches CHAR, `where type char = char where type string =
   String.string`, and has the 8-bit character set. *)
structure TestCharSig =
struct
  structure C : SPEC_CHAR where type char = char where type string = String.string = Char
  val () = T.check ("Char:CHAR/matches", fn () => true)
  val () = T.check ("Char:CHAR/char-is-toplevel", fn () => ord (C.chr 65 : char) = 65)
  val () = T.check ("Char:CHAR/toplevel-is-char", fn () => C.ord (#"A" : C.char) = 65)
  val () = T.check ("Char:CHAR/string-is-toplevel", fn () => C.contains ("abc" : string) #"b")
  val () = T.check ("Char:CHAR/string-is-String.string", fn () => size (C.toString #"a" : C.string) = 1)
  val () = T.check ("Char:CHAR/maxOrd-255", fn () => C.maxOrd = 255)
end
