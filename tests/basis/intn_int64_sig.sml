(* requires: Int64 FixedInt LargeInt StringCvt *)
(* uses: spec-sigs/INTEGER.sml *)
(* Int64 matches INTEGER, and so does FixedInt, the largest of the
   fixed-precision integers; here both are Int. *)
structure TestInt64Sig =
struct
  structure C : SPEC_INTEGER = Int64
  val () = T.check ("Int64:INTEGER/matches", fn () => true)
  val () = T.check ("Int64:INTEGER/precision-64", fn () => C.precision = SOME 64)
  structure F : SPEC_INTEGER = FixedInt
  val () = T.check ("FixedInt:INTEGER/matches", fn () => true)
  val () = T.check ("FixedInt:INTEGER/has-a-precision", fn () => isSome F.precision)
end
