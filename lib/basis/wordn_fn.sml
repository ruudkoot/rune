(* WordN: words of `wordSize` bits (less than 64), kept in a word of the VM
   whose upper bits are zero; every operation that could set one of them
   clears it again, as Word8 does. One file per instance (word16.sml,
   word32.sml); Word64 is Word itself. *)
functor RuneWordNFn (val wordSize : int) :> WORD =
struct
  type word = Word.word
  val wordSize = wordSize
  val low : Word.word = Word.- (Word.<< (0w1, Word.fromInt wordSize), 0w1)
  val signBit : Word.word = Word.<< (0w1, Word.fromInt (Int.- (wordSize, 1)))
  fun keep (w : Word.word) = Word.andb (w, low)

  (* the word with the sign bit of the N bits extended *)
  fun extend (w : Word.word) = if Word.>= (w, signBit) then Word.orb (w, Word.notb low) else w

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
