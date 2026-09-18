(* Word8: 8-bit words. A value is a word whose upper bits are zero; every
   operation that could set one of them clears it again. (The only member of
   the WordN family so far; see docs/plans/basis.md.) *)
structure Word8 :> WORD =
struct
  type word = Word.word
  val wordSize = 8
  val low : Word.word = 0wxFF
  fun keep (w : Word.word) = Word.andb (w, low)

  (* the word with the sign bit of the byte extended *)
  fun extend (w : Word.word) = if Word.>= (w, 0wx80) then Word.orb (w, Word.notb low) else w

  fun toLarge w = w
  val toLargeX = extend
  val toLargeWord = toLarge
  val toLargeWordX = toLargeX
  val fromLarge = keep
  val fromLargeWord = keep
  val toLargeInt = Word.toLargeInt
  fun toLargeIntX w = Word.toLargeIntX (extend w)
  fun fromLargeInt i = keep (Word.fromLargeInt i)
  val toInt = Word.toInt
  fun toIntX w = Word.toIntX (extend w)
  fun fromInt i = keep (Word.fromInt i)

  val andb = Word.andb
  val orb = Word.orb
  val xorb = Word.xorb
  fun notb w = keep (Word.notb w)
  fun << (w, n) = keep (Word.<< (w, n))
  val >> = Word.>>
  fun ~>> (w, n) = keep (Word.~>> (extend w, n))

  fun op + (a, b) = keep (Word.+ (a, b))
  fun op - (a, b) = keep (Word.- (a, b))
  fun op * (a, b) = keep (Word.* (a, b))
  val op div = Word.div
  val op mod = Word.mod
  fun ~ w = keep (Word.~ w)
  val compare = Word.compare
  val op < = Word.<
  val op <= = Word.<=
  val op > = Word.>
  val op >= = Word.>=
  val min = Word.min
  val max = Word.max

  val fmt = Word.fmt
  val toString = Word.toString
  fun scan radix getc src =
    case Word.scan radix getc src of
      SOME (w, rest) => if Word.> (w, low) then raise Overflow else SOME (w, rest)
    | NONE => NONE
  fun fromString s = StringCvt.scanString (scan StringCvt.HEX) s
end

_overload word Word8 8
