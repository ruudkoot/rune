(* requires: Int32 LargeInt StringCvt *)
(* uses: fn/numstr.sml fn/integer_fn.sml fn/integer_scan_fn.sml *)
(* Int32 (signature INTEGER): the checks that hold for every INTEGER
   structure, from fn/integer_fn.sml and fn/integer_scan_fn.sml, and the
   constants of the type. Expected values follow the text of
   https://smlfamily.github.io/Basis/integer.html. *)
structure TestInt32 =
struct
  structure Generic = TestIntegerFn (structure I = Int32 val name = "Int32")
  structure Scan = TestIntegerScanFn (structure I = Int32 val name = "Int32")
  (* Integer constants and the overloaded operators at Int32.int. A host
     that compiles lib/basis (xc1) has its own, closed overloading, which
     does not know the Int32 of lib/basis. *)
  (*<< constants *)
  val eqI = T.eq (fn i => Int32.toString i)
  val () = eqI ("Int32.+/overloaded", 2147483647, fn () => (1073741823 : Int32.int) + 1073741824)
  val () = T.raises ("Int32.+/overloaded-Overflow", T.isOverflow, fn () => (2147483647 : Int32.int) + 1)
  val () = eqI ("Int32.~/overloaded-minInt", ~2147483647 - 1, fn () => ~ (2147483647 : Int32.int) - 1)
  val () = T.check ("Int32.maxInt/constant", fn () => Int32.maxInt = SOME 2147483647)
  (*>> constants *)
end
