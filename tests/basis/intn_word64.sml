(* requires: Word64 LargeWord LargeInt StringCvt *)
(* uses: fn/numstr.sml fn/word_fn.sml fn/word_large_fn.sml fn/word_scan_fn.sml *)
(* Word64 (signature WORD): the checks that hold for every WORD structure,
   from fn/word_fn.sml, fn/word_large_fn.sml and fn/word_scan_fn.sml, and the
   constants of the type. Expected values follow the text of
   https://smlfamily.github.io/Basis/word.html. *)
structure TestWord64 =
struct
  structure Generic = TestWordFn (structure W = Word64 val name = "Word64")
  structure Large = TestWordLargeFn (structure W = Word64 val name = "Word64")
  structure Scan = TestWordScanFn (structure W = Word64 val name = "Word64")
  val () = T.eq T.int ("Word64.wordSize/64", 64, fn () => Word64.wordSize)
end
