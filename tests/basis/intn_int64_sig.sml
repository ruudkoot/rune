(* requires: Int64 LargeInt StringCvt *)
(* uses: spec-sigs/INTEGER.sml *)
(* Int64 matches INTEGER. *)
structure TestInt64Sig =
struct
  structure C : SPEC_INTEGER = Int64
  val () = T.check ("Int64:INTEGER/matches", fn () => true)
  val () = T.check ("Int64:INTEGER/precision-64", fn () => C.precision = SOME 64)
end
