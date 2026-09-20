(* requires: IntInf StringCvt *)
(* uses: fn/numstr.sml fn/integer_scan_fn.sml *)
(* IntInf.fmt and IntInf.scan, and IntInf.toString and IntInf.fromString in
   terms of them. Expected values follow the text of
   https://smlfamily.github.io/Basis/integer.html; the checks are those of
   every INTEGER structure, in fn/integer_scan_fn.sml. *)
structure TestIntInfScan =
struct
  structure Generic = TestIntegerScanFn (structure I = IntInf val name = "IntInf")
end
