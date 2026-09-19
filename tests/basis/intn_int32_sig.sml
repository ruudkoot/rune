(* requires: Int32 LargeInt StringCvt *)
(* uses: spec-sigs/INTEGER.sml *)
(* Int32 matches INTEGER. *)
structure TestInt32Sig =
struct
  structure C : SPEC_INTEGER = Int32
  val () = T.check ("Int32:INTEGER/matches", fn () => true)
  val () = T.check ("Int32:INTEGER/precision-32", fn () => C.precision = SOME 32)
end
