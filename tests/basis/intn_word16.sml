(* requires: Word16 LargeWord LargeInt StringCvt *)
(* uses: fn/numstr.sml fn/word_fn.sml fn/word_large_fn.sml fn/word_scan_fn.sml *)
(* Word16 (signature WORD): the checks that hold for every WORD structure,
   from fn/word_fn.sml, fn/word_large_fn.sml and fn/word_scan_fn.sml, and the
   constants of the type. Expected values follow the text of
   https://smlfamily.github.io/Basis/word.html. *)
structure TestWord16 =
struct
  structure Generic = TestWordFn (structure W = Word16 val name = "Word16")
  structure Large = TestWordLargeFn (structure W = Word16 val name = "Word16")
  structure Scan = TestWordScanFn (structure W = Word16 val name = "Word16")
  val () = T.eq T.int ("Word16.wordSize/16", 16, fn () => Word16.wordSize)
  (* Word constants and the overloaded operators at Word16.word; xc1 has
     the host's closed overloading (see intn_int8.sml). *)
  (*<< constants *)
  val eqW = T.eq (fn w => "0wx" ^ Word16.toString w)
  val () = eqW ("Word16.+/wraps", 0w4, fn () => (0wxFFFF : Word16.word) + 0w5)
  val () = eqW ("Word16.notb/16-bits", 0wxFFFF, fn () => Word16.notb 0w0)
  val () = T.eq T.int ("Word16.toIntX/all-ones-constant", ~1, fn () => Word16.toIntX 0wxFFFF)
  (*>> constants *)
end
