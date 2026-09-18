(* Int: 64-bit integers with Overflow checking. *)
structure Int =
struct
  type int = int
  val precision = SOME 64
  val minInt = SOME ~9223372036854775808
  val maxInt = SOME 9223372036854775807

  val toInt = fn (x : int) => x
  val fromInt = fn (x : int) => x
  val toLarge = IntInf.fromInt
  val fromLarge = IntInf.toInt

  val op + = _prim "int_add" : int * int -> int
  val op - = _prim "int_sub" : int * int -> int
  val op * = _prim "int_mul" : int * int -> int
  val op div = _prim "int_div" : int * int -> int
  val op mod = _prim "int_mod" : int * int -> int
  val quot = _prim "int_quot" : int * int -> int
  val rem = _prim "int_rem" : int * int -> int
  val ~ = _prim "int_neg" : int -> int
  val abs = _prim "int_abs" : int -> int
  val op < = _prim "int_lt" : int * int -> bool
  val op <= = _prim "int_le" : int * int -> bool
  val op > = _prim "int_gt" : int * int -> bool
  val op >= = _prim "int_ge" : int * int -> bool

  fun min (a : int, b) = if a < b then a else b
  fun max (a : int, b) = if a > b then a else b
  fun sign (a : int) = if a < 0 then ~1 else if a > 0 then 1 else 0
  fun sameSign (a, b) = sign a = sign b
  fun compare (a : int, b) = if a < b then LESS else if a = b then EQUAL else GREATER

  val toString = _prim "int_to_string" : int -> string
  val fromString = _prim "int_from_string" : string -> int option
end
