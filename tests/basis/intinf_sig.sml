(* requires: IntInf LargeInt StringCvt *)
(* uses: spec-sigs/INTEGER.sml spec-sigs/INT_INF.sml *)
(* IntInf matches INT_INF, and LargeInt.int is IntInf.int. *)
structure TestIntInfSig =
struct
  structure C : SPEC_INT_INF = IntInf
  val () = T.check ("IntInf:INT_INF/matches", fn () => true)
  val () = T.check ("IntInf:INT_INF/int-is-IntInf.int",
                    fn () => (C.fromInt 1 : C.int) = (IntInf.fromInt 1 : IntInf.int))
  (* INT_INF includes INTEGER, so IntInf matches that as well. *)
  structure I : SPEC_INTEGER = IntInf
  val () = T.check ("IntInf:INTEGER/matches", fn () => true)
  (* "If an implementation provides the IntInf structure, then LargeInt must
     be the same structure as IntInf (viewed through a thinning INTEGER
     signature)." *)
  (* alias: LargeInt = IntInf *)
  structure D : SPEC_INTEGER = LargeInt
  val () = T.check ("LargeInt:INTEGER/matches", fn () => true)
  val () = T.check ("LargeInt:INTEGER/int-is-IntInf.int",
                    fn () => (D.fromInt 1 : D.int) = (IntInf.fromInt 1 : IntInf.int))
end
