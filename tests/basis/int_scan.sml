(* requires: Int StringCvt *)
(* uses: fn/numstr.sml fn/integer_scan_fn.sml *)
(* Int.fmt and Int.scan, and Int.toString and Int.fromString in terms of
   them. Expected values follow the text of
   https://smlfamily.github.io/Basis/integer.html; the checks are those of
   every INTEGER structure, in fn/integer_scan_fn.sml. *)
structure TestIntScan =
struct
  structure Generic = TestIntegerScanFn (structure I = Int val name = "Int")
end
