(* Word: unsigned words: 64 bits on the VM. The size is found by shifting a
   bit out, so that this file means the same to a system whose word is
   narrower. *)
structure Word =
struct
  type word = word
  val wordSize =
    let
      val shl = _prim "word_lsl" : word * word -> word
      fun count (w, n) = if w = 0w0 then n else count (shl (w, 0w1), Int.+ (n, 1))
    in count (0w1, 0) end

  val toInt = _prim "word_to_int" : word -> int
  val toIntX = _prim "word_to_int_x" : word -> int
  val fromInt = _prim "word_from_int" : int -> word
  val toLarge = fn (w : word) => w
  val fromLarge = fn (w : word) => w
  val two64 = IntInf.pow (IntInf.fromInt 2, wordSize)             (* 2^wordSize *)
  val two63 = IntInf.pow (IntInf.fromInt 2, Int.- (wordSize, 1))  (* 2^(wordSize - 1) *)
  fun toLargeInt w = let val i = toIntX w in if Int.< (i, 0) then IntInf.+ (IntInf.fromInt i, two64) else IntInf.fromInt i end
  fun toLargeIntX w = IntInf.fromInt (toIntX w)
  fun fromLargeInt x =
    let val r = IntInf.mod (x, two64)
    in fromInt (IntInf.toInt (if IntInf.>= (r, two63) then IntInf.- (r, two64) else r)) end

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
      if n >= fromInt wordSize then (if negative then notb 0w0 else 0w0)
      else
        let val shifted = >> (w, n)
        in if negative then orb (shifted, notb (>> (notb 0w0, n))) else shifted end
    end
  val ~ = _prim "word_neg" : word -> word

  fun min (a : word, b) = if a < b then a else b
  fun max (a : word, b) = if a > b then a else b
  fun compare (a : word, b) = if a < b then LESS else if a = b then EQUAL else GREATER

  val toString = _prim "word_to_string" : word -> string

  fun base StringCvt.BIN = 0w2
    | base StringCvt.OCT = 0w8
    | base StringCvt.DEC = 0w10
    | base StringCvt.HEX = 0w16

  fun fmt radix (w : word) =
    let
      val r = base radix
      fun digit d = let val d = toInt d in chr (if Int.< (d, 10) then Int.+ (48, d) else Int.+ (55, d)) end
      fun go (w, acc) =
        let val acc = digit (w mod r) :: acc
            val w = w div r
        in if w = 0w0 then acc else go (w, acc) end
    in implode (go (w, [])) end

  (* (0w)?digits, in radix HEX (0wx | 0wX | 0x | 0X)?digits. A prefix counts
     only when a digit follows it: "0wxg" is 0 and leaves "wxg". Overflow if
     the number does not fit. *)
  fun scan radix (getc : (char, 'a) StringCvt.reader) src =
    let
      val r = base radix
      fun digitValue c =
        case Int.digitValue (toInt r, c) of SOME d => SOME (fromInt d) | NONE => NONE
      fun isDigitNext src =
        case getc src of SOME (c, _) => (case digitValue c of SOME _ => true | NONE => false) | NONE => false
      val src = StringCvt.skipWS getc src
      (* the stream after the characters cs, if they are next and a digit follows them *)
      fun prefix ([], rest) = if isDigitNext rest then SOME rest else NONE
        | prefix (c :: cs, rest) =
          (case getc rest of
             SOME (c', rest') => if List.exists (fn x => x = c') c then prefix (cs, rest') else NONE
           | NONE => NONE)
      val prefixes =
        if r = 0w16 then [[[#"0"], [#"w"], [#"x", #"X"]], [[#"0"], [#"x", #"X"]]]
        else [[[#"0"], [#"w"]]]
      fun strip [] = src
        | strip (p :: ps) = (case prefix (p, src) of SOME rest => rest | NONE => strip ps)
      val src = strip prefixes
      val limit = notb 0w0 div r
      fun digits (src, acc) =
        case getc src of
          SOME (c, rest) =>
            (case digitValue c of
               SOME d =>
                 if acc > limit then raise Overflow
                 else
                   let val shifted = acc * r
                       val sum = shifted + d
                   in if sum < shifted then raise Overflow else digits (rest, sum) end
             | NONE => (acc, src))
        | NONE => (acc, src)
    in
      if isDigitNext src then SOME (digits (src, 0w0)) else NONE
    end

  fun fromString s = StringCvt.scanString (scan StringCvt.HEX) s

  (* LargeWord is Word *)
  val toLargeX = toLarge
  val toLargeWord = toLarge
  val toLargeWordX = toLarge
  val fromLargeWord = fromLarge
end

structure LargeWord = Word
