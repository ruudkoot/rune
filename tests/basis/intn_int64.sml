(* requires: Int64 LargeInt StringCvt *)
(* uses: fn/numstr.sml fn/integer_fn.sml fn/integer_scan_fn.sml *)
(* Int64 (signature INTEGER): the checks that hold for every INTEGER
   structure, from fn/integer_fn.sml and fn/integer_scan_fn.sml, and the
   constants of the type. Expected values follow the text of
   https://smlfamily.github.io/Basis/integer.html. *)
structure TestInt64 =
struct
  structure Generic = TestIntegerFn (structure I = Int64 val name = "Int64")
  structure Scan = TestIntegerScanFn (structure I = Int64 val name = "Int64")
  (* "Int64 ... FixedInt": Rune's Int has 64 bits, so these are Int *)
  val () = T.check ("Int64.precision/64", fn () => Int64.precision = SOME 64)
end
