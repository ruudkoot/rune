(* What SML/NJ 2026.2's InlineT (target64-inline.sml) adds to 110.99.9's,
   which ../smlnj-legacy/inline.sml makes and this extends: ptrEq and
   ptrNeq, Int63 (Int by its other name), and for Word, Word8, Word32 and
   Word64 the operations by which 2026.2's library makes those of WORD_2026
   (rotateL, countOnes, ceilLog2, ...). SML/NJ's compiler makes them of
   its own primitives (FLINT/trans/transprim.sml); here they are made of
   a word's bits in a Word64.word, with the same results: a rotation by
   its amount modulo the width, and ceilLog2 the width less the leading
   zeros of w - 1, after a word of fewer than 63 bits is made one of 63,
   so that ceilLog2 0w0 is 63, or 64 for a Word64.word. *)
functor XC2NBitOps (type word
                    val width : int
                    val toLarge : word -> Word64.word
                    val fromLarge : Word64.word -> word) =
struct
  val mask : Word64.word = if width >= 64 then Word64.notb 0w0 else Word64.<< (0w1, Word.fromInt width) - 0w1
  fun bit (x, k) = Word64.andb (Word64.>> (x, Word.fromInt k), 0w1) = 0w1
  fun rotateL (w : word, n : Word.word) =
    let val k = Word.toInt (n mod Word.fromInt width)
        val x = toLarge w
    in if k = 0 then w
       else fromLarge (Word64.andb (Word64.orb (Word64.<< (x, Word.fromInt k), Word64.>> (x, Word.fromInt (width - k))), mask))
    end
  fun rotateR (w, n : Word.word) =
    rotateL (w, Word.fromInt ((width - Word.toInt (n mod Word.fromInt width)) mod width))
  fun cntOnes (w : word) =
    let fun go (x, n) = if x = 0w0 then n else go (Word64.andb (x, x - 0w1), n + 1) in go (toLarge w, 0) end
  fun cntZeros w = width - cntOnes w
  fun cntLeadingZeros (w : word) =
    let val x = toLarge w
        fun go k = if k < 0 then width else if bit (x, k) then width - 1 - k else go (k - 1)
    in go (width - 1) end
  fun cntTrailingZeros (w : word) =
    let val x = toLarge w
        fun go k = if k >= width then width else if bit (x, k) then k else go (k + 1)
    in go 0 end
  fun complement (w : word) = fromLarge (Word64.andb (Word64.notb (toLarge w), mask))
  fun cntLeadingOnes w = cntLeadingZeros (complement w)
  fun cntTrailingOnes w = cntTrailingZeros (complement w)
  fun isPowOf2 (w : word) = let val x = toLarge w in x <> 0w0 andalso Word64.andb (x, x - 0w1) = 0w0 end
  (* the least k with 2^k >= w, for w > 0 *)
  fun ceilLog2 (w : word) : Word.word =
    let val x = toLarge w
        fun go (k, p) = if k >= width orelse Word64.>= (p, x) then k else go (k + 1, Word64.<< (p, 0w1))
    in if x = 0w0 then (if width = 64 then 0w64 else 0w63) else Word.fromInt (go (0, 0w1)) end
  structure Ops =
  struct
    val rotateL = rotateL val rotateR = rotateR
    val cntZeros = cntZeros val cntOnes = cntOnes
    val cntLeadingZeros = cntLeadingZeros val cntLeadingOnes = cntLeadingOnes
    val cntTrailingZeros = cntTrailingZeros val cntTrailingOnes = cntTrailingOnes
    val isPowOf2 = isPowOf2 val ceilLog2 = ceilLog2
  end
end

(* applied here, where Word, Word8, ... are still Rune's and not InlineT's *)
structure XC2NWordBits = XC2NBitOps (type word = word val width = 63 val toLarge = Word.toLarge val fromLarge = Word.fromLarge)
structure XC2NWord8Bits = XC2NBitOps (type word = Word8.word val width = 8 val toLarge = Word8.toLarge val fromLarge = Word8.fromLarge)
structure XC2NWord32Bits = XC2NBitOps (type word = Word32.word val width = 32 val toLarge = Word32.toLarge val fromLarge = Word32.fromLarge)
structure XC2NWord64Bits = XC2NBitOps (type word = Word64.word val width = 64 val toLarge = fn w => w val fromLarge = fn w => w)

structure InlineT =
struct
  open InlineT
  val ptrEq = ptreql
  fun ptrNeq (a, b) = not (ptreql (a, b))
  structure Int63 = Int
  structure Word = struct open Word XC2NWordBits.Ops end
  structure Word8 = struct open Word8 XC2NWord8Bits.Ops end
  structure Word32 = struct open Word32 XC2NWord32Bits.Ops end
  structure Word64 = struct open Word64 XC2NWord64Bits.Ops end
end
