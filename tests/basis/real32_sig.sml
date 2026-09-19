(* requires: Real32 *)
(* uses: spec-sigs/MATH.sml spec-sigs/REAL.sml *)
(* Real32 matches REAL, its substructure Math shares its type, and its type
   is not real (binary64 on the systems of the matrix). *)
structure TestReal32Sig =
struct
  structure C : SPEC_REAL = Real32
  val () = T.check ("Real32:REAL/matches", fn () => true)
  val () = T.check ("Real32:REAL/Math-shares-real",
                    fn () => C.== (C.Math.sqrt (C.fromInt 4), C.fromInt 2))
  val () = T.check ("Real32:REAL/toLarge-gives-LargeReal.real",
                    fn () => LargeReal.== (C.toLarge (C.fromInt 3), LargeReal.fromInt 3))
end
