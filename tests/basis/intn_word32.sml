(* requires: Word32 LargeWord LargeInt StringCvt *)
(* uses: fn/numstr.sml fn/word_fn.sml fn/word_large_fn.sml fn/word_scan_fn.sml *)
(* Word32 (signature WORD): the checks that hold for every WORD structure,
   from fn/word_fn.sml, fn/word_large_fn.sml and fn/word_scan_fn.sml, and the
   constants of the type. Expected values follow the text of
   https://smlfamily.github.io/Basis/word.html. *)
structure TestWord32 =
struct
  structure Generic = TestWordFn (structure W = Word32 val name = "Word32")
  structure Large = TestWordLargeFn (structure W = Word32 val name = "Word32")
  structure Scan = TestWordScanFn (structure W = Word32 val name = "Word32")
  val () = T.eq T.int ("Word32.wordSize/32", 32, fn () => Word32.wordSize)
  (* Word constants and the overloaded operators at Word32.word; xc1 has
     the host's closed overloading (see intn_int8.sml). *)
  (*<< constants *)
  val eqW = T.eq (fn w => "0wx" ^ Word32.toString w)
  val () = eqW ("Word32.+/wraps", 0w4, fn () => (0wxFFFFFFFF : Word32.word) + 0w5)
  val () = eqW ("Word32.notb/32-bits", 0wxFFFFFFFF, fn () => Word32.notb 0w0)
  val () = T.eq T.int ("Word32.toIntX/all-ones-constant", ~1, fn () => Word32.toIntX 0wxFFFFFFFF)
  (*>> constants *)
end
