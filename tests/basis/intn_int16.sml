(* requires: Int16 LargeInt StringCvt *)
(* uses: fn/numstr.sml fn/integer_fn.sml fn/integer_scan_fn.sml *)
(* Int16 (signature INTEGER): the checks that hold for every INTEGER
   structure, from fn/integer_fn.sml and fn/integer_scan_fn.sml, and the
   constants of the type. Expected values follow the text of
   https://smlfamily.github.io/Basis/integer.html. *)
structure TestInt16 =
struct
  structure Generic = TestIntegerFn (structure I = Int16 val name = "Int16")
  structure Scan = TestIntegerScanFn (structure I = Int16 val name = "Int16")
  (* Integer constants and the overloaded operators at Int16.int. A host
     that compiles lib/basis (xc1) has its own, closed overloading, which
     does not know the Int16 of lib/basis. *)
  (*<< constants *)
  val eqI = T.eq (fn i => Int16.toString i)
  val () = eqI ("Int16.+/overloaded", 32767, fn () => (16383 : Int16.int) + 16384)
  val () = T.raises ("Int16.+/overloaded-Overflow", T.isOverflow, fn () => (32767 : Int16.int) + 1)
  val () = eqI ("Int16.~/overloaded-minInt", ~32767 - 1, fn () => ~ (32767 : Int16.int) - 1)
  val () = T.check ("Int16.maxInt/constant", fn () => Int16.maxInt = SOME 32767)
  (*>> constants *)
end
