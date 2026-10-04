(* Word64: the 64-bit words, and LargeWord, the widest ones, which is the same
   structure.

   The type is the VM's own 64-bit word and not `Word.word`, whose width the
   VM decides (63 bits: a word of the VM with a bit taken for its tag). A
   number here is kept in such a word where it fits and in a small object
   where it needs the 64th bit. This is the type for hashes, checksums,
   random number generators and whatever else is written for 64 bits.

   Implements: WORD

   Status: optional *)
structure Word64 =
struct
  type word = _prim "word64"
  val wordSize = 64

  val toInt = _prim "word64_to_int" : word -> int
  val toIntX = _prim "word64_to_int_x" : word -> int
  val fromInt = _prim "word64_from_int" : int -> word
  val toLarge = fn (w : word) => w
  val toLargeX = toLarge
  val fromLarge = fn (w : word) => w

  val op + = _prim "word64_add" : word * word -> word
  val op - = _prim "word64_sub" : word * word -> word
  val op * = _prim "word64_mul" : word * word -> word
  val op div = _prim "word64_div" : word * word -> word
  val op mod = _prim "word64_mod" : word * word -> word
  val op < = _prim "word64_lt" : word * word -> bool
  val op <= = _prim "word64_le" : word * word -> bool
  val op > = _prim "word64_gt" : word * word -> bool
  val op >= = _prim "word64_ge" : word * word -> bool
  val andb = _prim "word64_andb" : word * word -> word
  val orb = _prim "word64_orb" : word * word -> word
  val xorb = _prim "word64_xorb" : word * word -> word
  val notb = _prim "word64_notb" : word -> word
  val op << = _prim "word64_lsl" : word * Word.word -> word
  val op >> = _prim "word64_lsr" : word * Word.word -> word
  val ~>> = _prim "word64_asr" : word * Word.word -> word
  val ~ = _prim "word64_neg" : word -> word

  (* through the two halves, each of which an int holds *)
  local
    val two32 = IntInf.fromInt 4294967296
    val two64 = IntInf.* (two32, two32)
    val two63 = IntInf.div (two64, IntInf.fromInt 2)
  in
    fun toLargeInt (w : word) =
      IntInf.+ (IntInf.* (IntInf.fromInt (toInt (>> (w, 0w32))), two32), IntInf.fromInt (toInt (andb (w, 0wxFFFFFFFF))))
    fun toLargeIntX w = let val i = toLargeInt w in if IntInf.>= (i, two63) then IntInf.- (i, two64) else i end
    fun fromLargeInt x =
      let val (q, r) = IntInf.divMod (IntInf.mod (x, two64), two32)
      in orb (<< (fromInt (IntInf.toInt q), 0w32), fromInt (IntInf.toInt r)) end
  end

  fun min (a : word, b) = if a < b then a else b
  fun max (a : word, b) = if a > b then a else b
  val compare = _prim "word64_order" : word * word -> order

  val toString = _prim "word64_to_string" : word -> string

  fun base StringCvt.BIN = 0w2
    | base StringCvt.OCT = 0w8
    | base StringCvt.DEC = 0w10
    | base StringCvt.HEX = (0w16 : word)

  fun fmt radix (w : word) =
    let
      val r = base radix
      fun digit d = let val d = toInt d in chr (if Int.< (d, 10) then Int.+ (48, d) else Int.+ (55, d)) end
      fun go (w, acc) =
        let val acc = digit (w mod r) :: acc
            val w = w div r
        in if w = 0w0 then acc else go (w, acc) end
    in implode (go (w, [])) end

  (* As Word.scan: (0w)?digits, in radix HEX (0wx | 0wX | 0x | 0X)?digits; a
     prefix counts only when a digit follows it. Overflow if the number does
     not fit. *)
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
      fun digits (src, acc : word) =
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

  (* LargeWord is this structure *)
  val toLargeWord = toLarge
  val toLargeWordX = toLargeX
  val fromLargeWord = fromLarge
end

(* LargeWord: the widest words, which are `Word64`.

   Implements: WORD *)
structure LargeWord = Word64
