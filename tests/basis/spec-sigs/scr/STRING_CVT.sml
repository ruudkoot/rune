(* signature STRING_CVT as the change request of docs/unicode.md writes it (the
   deviation `STRING_CVT/generic` of lib/basis): the transcription of STRING_CVT.sml,
   with the types of the text the signature's own. Not the page: a test that
   matches a structure against this checks the change request, and so does
   scripts/gen-basis-sigs.sh, which holds the library's STRING_CVT to this
   instead of to the page's. *)
signature SCR_STRING_CVT =
sig
  eqtype char
  eqtype string
  datatype radix = BIN | OCT | DEC | HEX
  datatype realfmt
    = SCI of int option
    | FIX of int option
    | GEN of int option
    | EXACT
  type ('a, 'b) reader = 'b -> ('a * 'b) option

  val padLeft : char -> int -> string -> string
  val padRight : char -> int -> string -> string
  val splitl : (char -> bool) -> (char, 'a) reader -> 'a -> string * 'a
  val takel : (char -> bool) -> (char, 'a) reader -> 'a -> string
  val dropl : (char -> bool) -> (char, 'a) reader -> 'a -> 'a
  val skipWS : (char, 'a) reader -> 'a -> 'a
  type cs
  val scanString : ((char, cs) reader -> ('a, cs) reader) -> string -> 'a option
end
