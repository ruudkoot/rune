(* JSON (RFC 8259): values read from text and written back.

   Reading is strict: the grammar of RFC 8259 and nothing beside it -- no
   comments, no trailing commas, no single quotes, no NaN -- in UTF-8, as the
   RFC requires of text exchanged between systems; a string's escapes must
   name scalar values, so a lone surrogate is an error. A number is kept as
   the text it was written in, so that nothing is lost to a conversion that
   the program did not ask for; `int` and `toInt` convert. An object keeps
   its members in the order they were written, a repeated name included.
   Nesting deeper than `maxDepth` is refused rather than followed.

   Area: Data formats *)
signature JSON =
sig
  (* A JSON value. *)
  datatype value =
      Null
    | Bool of bool
    | Number of string             (* as written: `-? int frac? exp?` of the RFC's grammar *)
    | String of string             (* UTF-8 *)
    | Array of value list
    | Object of (string * value) list

  (* What `decode` raises: the byte offset where the text stops being JSON,
     and what is wrong there. *)
  exception Syntax of int * string

  (* How deeply arrays and objects may nest in a text `decode` reads.

     Example: `maxDepth = 512` *)
  val maxDepth : int

  (* `decode s` is the value the JSON text `s` is.

     Raises: `Syntax` if `s` is not one JSON value with only blanks around
     it, or nests deeper than `maxDepth`.

     Example: `decode " [1, \"two\", null] " = Array [Number "1", String "two", Null]` *)
  val decode : string -> value

  (* `encode v` is `v` written as compact JSON text: no blank between
     tokens, `"`, `\` and the control characters escaped, the rest of the
     UTF-8 of strings left as it is.

     Raises: `Domain` if a string of `v` is not valid UTF-8, or a `Number`
     is not a number of the RFC's grammar.

     Reading back what it writes gives `v` again;
     tests/lib/json/roundtrip.sml checks that on random values.

     Example: `encode (Object [("a", Array [Bool true, String "\n"])]) =
     "{\"a\":[true,\"\\n\"]}"` *)
  val encode : value -> string

  (* `encodeIndented n v` is `v` written as JSON text with each element and
     member on a line of its own, indented by `n` blanks a level.

     Raises: `Domain` where `encode` would.

     Example: `encodeIndented 2 (Array [Null]) = "[\n  null\n]"` *)
  val encodeIndented : int -> value -> string

  (* `int i` is the number `i`.

     Example: `int ~3 = Number "-3"` *)
  val int : int -> value

  (* `toInt v` is the integer `v` is, when it is a `Number` with no
     fraction or exponent that fits an `int`; `NONE` otherwise.

     Example: `toInt (Number "-42") = SOME ~42 andalso toInt (Number "4.2") = NONE` *)
  val toInt : value -> int option

  (* `member (name, v)` is the value of the first member called `name` of
     the object `v`, or `NONE` when `v` is not an object or has none.

     Example: `member ("b", Object [("a", Null), ("b", Bool false)]) = SOME (Bool false)` *)
  val member : string * value -> value option
end
