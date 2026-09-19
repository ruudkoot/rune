(* requires: Int8 LargeInt StringCvt *)
(* uses: fn/numstr.sml fn/integer_fn.sml fn/integer_scan_fn.sml *)
(* Int8 (signature INTEGER): the checks that hold for every INTEGER
   structure, from fn/integer_fn.sml and fn/integer_scan_fn.sml, and the
   constants of the type. Expected values follow the text of
   https://smlfamily.github.io/Basis/integer.html. *)
structure TestInt8 =
struct
  structure Generic = TestIntegerFn (structure I = Int8 val name = "Int8")
  structure Scan = TestIntegerScanFn (structure I = Int8 val name = "Int8")
  (* Integer constants and the overloaded operators at Int8.int. A host
     that compiles lib/basis (xc1) has its own, closed overloading, which
     does not know the Int8 of lib/basis. *)
  (*<< constants *)
  val eqI = T.eq (fn i => Int8.toString i)
  val () = eqI ("Int8.+/overloaded", 127, fn () => (63 : Int8.int) + 64)
  val () = T.raises ("Int8.+/overloaded-Overflow", T.isOverflow, fn () => (127 : Int8.int) + 1)
  val () = eqI ("Int8.~/overloaded-minInt", ~127 - 1, fn () => ~ (127 : Int8.int) - 1)
  val () = T.check ("Int8.maxInt/constant", fn () => Int8.maxInt = SOME 127)
  (*>> constants *)
end
