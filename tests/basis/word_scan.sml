(* requires: Word StringCvt *)
(* uses: fn/numstr.sml fn/word_scan_fn.sml *)
(* Word.fmt and Word.scan, and Word.toString and Word.fromString in terms of
   them. Expected values follow the text of
   https://smlfamily.github.io/Basis/word.html; the checks are those of every
   WORD structure, in fn/word_scan_fn.sml. *)
structure TestWordScan =
struct
  structure Generic = TestWordScanFn (structure W = Word val name = "Word")
end
