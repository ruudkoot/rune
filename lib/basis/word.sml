(* Word: 64-bit unsigned words. *)
structure Word =
struct
  type word = word
  val wordSize = 64

  val toInt = _prim "word_to_int" : word -> int
  val toIntX = _prim "word_to_int_x" : word -> int
  val fromInt = _prim "word_from_int" : int -> word
  val toLarge = fn (w : word) => w
  val fromLarge = fn (w : word) => w
  val toLargeInt = toInt
  val toLargeIntX = toIntX
  val fromLargeInt = fromInt

  val op + = _prim "word_add" : word * word -> word
  val op - = _prim "word_sub" : word * word -> word
  val op * = _prim "word_mul" : word * word -> word
  val op div = _prim "word_div" : word * word -> word
  val op mod = _prim "word_mod" : word * word -> word
  val op < = _prim "word_lt" : word * word -> bool
  val op <= = _prim "word_le" : word * word -> bool
  val op > = _prim "word_gt" : word * word -> bool
  val op >= = _prim "word_ge" : word * word -> bool
  val andb = _prim "word_andb" : word * word -> word
  val orb = _prim "word_orb" : word * word -> word
  val xorb = _prim "word_xorb" : word * word -> word
  val notb = _prim "word_notb" : word -> word
  val op << = _prim "word_lsl" : word * word -> word
  val op >> = _prim "word_lsr" : word * word -> word
  fun ~>> (w, n) =
    let val negative = Int.< (toIntX w, 0)
    in
      if n >= 0w64 then (if negative then notb 0w0 else 0w0)
      else
        let val shifted = >> (w, n)
        in if negative then orb (shifted, notb (>> (notb 0w0, n))) else shifted end
    end
  fun ~ w = 0w0 - w

  fun min (a : word, b) = if a < b then a else b
  fun max (a : word, b) = if a > b then a else b
  fun compare (a : word, b) = if a < b then LESS else if a = b then EQUAL else GREATER

  val toString = _prim "word_to_string" : word -> string
  fun fromString s =
    let
      val ord = _prim "char_ord" : char -> int
      fun hexVal c =
        let val n = ord c
        in
          if Int.>= (n, 48) andalso Int.<= (n, 57) then SOME (fromInt (Int.- (n, 48)))
          else if Int.>= (n, 97) andalso Int.<= (n, 102) then SOME (fromInt (Int.- (n, 87)))
          else if Int.>= (n, 65) andalso Int.<= (n, 70) then SOME (fromInt (Int.- (n, 55)))
          else NONE
        end
      fun go ([], acc, any) = if any then SOME acc else NONE
        | go (c :: cs, acc, any) =
          case hexVal c of
            SOME d => go (cs, acc * 0w16 + d, true)
          | NONE => if any then SOME acc else NONE
      val cs = (_prim "string_explode" : string -> char list) s
      val cs = case cs of #"0" :: #"w" :: #"x" :: rest => rest
                        | #"0" :: #"x" :: rest => rest
                        | _ => cs
    in go (cs, 0w0, false) end
end
