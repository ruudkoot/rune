(* requires: Real *)
(* uses: spec-sigs/MATH.sml spec-sigs/REAL.sml *)
(* Real matches REAL "where type real = real", its substructure Math shares
   that type, and LargeReal matches REAL. On the four systems of the matrix
   both are the 64-bit IEEE doubles, so LargeReal.real is real as well. *)
structure TestRealSig =
struct
  structure C : SPEC_REAL = Real
  val () = T.check ("Real:REAL/matches", fn () => true)
  val () = T.check ("Real:REAL/real-is-toplevel", fn () => C.== (C.+ (1.5 : real, 2.0 : real), 3.5))
  val () = T.check ("Real:REAL/toplevel-is-real", fn () => (C.fromInt 2 : real) > 1.0)
  val () = T.check ("Real:REAL/Math-shares-real", fn () => C.== (C.Math.sqrt (C.fromInt 4), 2.0))
  val () = T.check ("Real:REAL/Math-is-toplevel-Math", fn () => C.== (C.Math.pi, Math.pi))
  val () = T.check ("Real:REAL/toplevel-conversions",
                    fn () => C.== (real 3, C.fromInt 3) andalso floor 2.5 = C.floor 2.5 andalso ceil 2.5 = C.ceil 2.5
                             andalso trunc 2.5 = C.trunc 2.5 andalso round 2.5 = C.round 2.5)

  structure W : SPEC_REAL where type real = real = Real
  val () = T.check ("Real:REAL/where-type-real", fn () => W.== (W.abs (~1.5), 1.5))

  (*<< largereal *)
  structure L : SPEC_REAL = LargeReal
  val () = T.check ("LargeReal:REAL/matches", fn () => true)
  val () = T.check ("LargeReal:REAL/Math-shares-real", fn () => L.== (L.Math.sqrt (L.fromInt 4), L.fromInt 2))
  val () = T.check ("LargeReal:REAL/toLarge-gives-LargeReal.real",
                    fn () => L.== (Real.toLarge 1.5, L./ (L.fromInt 3, L.fromInt 2)))
  (*>> largereal *)

  (* alias: LargeReal = Real *)
  (*<< largereal-alias *)
  (* Not required by the page ("If LargeReal is not the same as Real, then
     there must be a structure Real<N> equal to LargeReal"), but true of every
     system in the matrix. *)
  val () = T.check ("LargeReal:REAL/real-is-toplevel", fn () => LargeReal.== (1.5 : real, LargeReal.fromInt 3 / 2.0))
  val () = T.check ("LargeReal:REAL/same-precision", fn () => LargeReal.precision = Real.precision)
  (*>> largereal-alias *)
end
