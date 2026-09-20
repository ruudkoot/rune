(* requires: Word8 LargeWord LargeInt StringCvt *)
(* uses: fn/numstr.sml fn/word_fn.sml fn/word_large_fn.sml fn/word_scan_fn.sml *)
(* Word8 (signature WORD): the checks that hold for every WORD structure,
   from fn/word_fn.sml, fn/word_large_fn.sml and fn/word_scan_fn.sml, and
   word constants and the overloaded operators at the type. *)
structure TestWord8 =
struct
  structure Generic = TestWordFn (structure W = Word8 val name = "Word8")
  structure Large = TestWordLargeFn (structure W = Word8 val name = "Word8")
  structure Scan = TestWordScanFn (structure W = Word8 val name = "Word8")

  (* Word constants and the overloaded operators at Word8.word. A host that
     compiles lib/basis (xc1) has its own, closed overloading, which does not
     know the Word8 of lib/basis. *)
  (*<< constants *)
  val eqW = T.eq (fn w => "0wx" ^ Word8.toString w)
  val () = T.eq T.int ("Word8.wordSize/eight", 8, fn () => Word8.wordSize)
  val () = eqW ("Word8.+/wraps-at-256", 0w4, fn () => Word8.+ (0w250, 0w10))
  val () = eqW ("Word8.+/overloaded", 0w255, fn () => (0w250 : Word8.word) + 0w5)
  val () = eqW ("Word8.notb/eight-bits", 0wxF0, fn () => Word8.notb 0wx0F)
  val () = eqW ("Word8.~>>/sign-bit-constant", 0wxC0, fn () => Word8.~>> (0wx80, 0w1))
  val () = T.eq T.int ("Word8.toIntX/all-ones-constant", ~1, fn () => Word8.toIntX 0wxFF)
  val () = eqW ("Word8.fromInt/keeps-the-low-byte", 0wx34, fn () => Word8.fromInt 4660)
  val () = T.check ("Word8.</overloaded", fn () => (0w3 : Word8.word) < 0w200)
  (*>> constants *)
end
