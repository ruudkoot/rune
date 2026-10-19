(* dump: --passes=trees,shake,simplify --dump-after=simplify *)
(* A match on many strings (performance M5, D7 B): by the string's length --
   one string_size, a halving by int_lt and tests of imm_eq --, then, for a
   length of few strings, a string_eq of each; for one of many (the eight of
   three characters), by the character where they differ most, and a
   string_eq of the one it leaves. A string of no rule jumps to the join
   point of the last. *)
fun k s =
  case s of
    "and" => 1 | "end" => 2 | "fun" => 3 | "let" => 4 | "val" => 5 | "rec" => 6
  | "sig" => 7 | "use" => 8 | "in" => 9 | "of" => 10 | "local" => 11
  | _ => 0
val r = (k "val", k "in", k "x", k "local", k "vax")
