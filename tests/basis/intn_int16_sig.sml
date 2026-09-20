(* requires: Int16 LargeInt StringCvt *)
(* uses: spec-sigs/INTEGER.sml *)
(* Int16 matches INTEGER. *)
structure TestInt16Sig =
struct
  structure C : SPEC_INTEGER = Int16
  val () = T.check ("Int16:INTEGER/matches", fn () => true)
  val () = T.check ("Int16:INTEGER/precision-16", fn () => C.precision = SOME 16)
end
