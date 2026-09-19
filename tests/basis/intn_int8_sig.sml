(* requires: Int8 LargeInt StringCvt *)
(* uses: spec-sigs/INTEGER.sml *)
(* Int8 matches INTEGER. *)
structure TestInt8Sig =
struct
  structure C : SPEC_INTEGER = Int8
  val () = T.check ("Int8:INTEGER/matches", fn () => true)
  val () = T.check ("Int8:INTEGER/precision-8", fn () => C.precision = SOME 8)
end
