(* requires: Math *)
(* uses: spec-sigs/MATH.sml *)
(* Math matches MATH "where type real = Real.real", and Real.Math matches it
   with the same type. *)
structure TestMathSig =
struct
  structure C : SPEC_MATH = Math
  val () = T.check ("Math:MATH/matches", fn () => true)
  val () = T.check ("Math:MATH/real-is-toplevel", fn () => Real.== (C.sqrt (4.0 : real), 2.0))
  val () = T.check ("Math:MATH/toplevel-is-real", fn () => Real.> ((C.pi : real) + (C.e : Real.real), 5.0))

  (* "The top-level structure Math provides these functions for the default
     real type Real.real", as Real.Math does: the two agree, member by member,
     and the behaviour is checked once, in math.sml. *)
  (* alias: Real.Math = Math *)
  structure R : SPEC_MATH = Real.Math
  val () = T.check ("Math:MATH/Real.Math-matches", fn () => true)
  val () = T.check ("Math:MATH/Real.Math-real-is-toplevel", fn () => Real.== (R.sqrt (C.sqrt (16.0 : real)), 2.0))
  val () = T.check ("Math:MATH/Real.Math-agrees-with-Math", fn () =>
             T.sameReal (R.pi, C.pi) andalso T.sameReal (R.e, C.e)
             andalso List.all (fn (f, g) => List.all (fn x => T.sameReal (f x, g x)) [0.0, 0.5, ~0.75, 2.5, ~1E10, Real.posInf])
                       [(R.sqrt, C.sqrt), (R.sin, C.sin), (R.cos, C.cos), (R.tan, C.tan), (R.asin, C.asin),
                        (R.acos, C.acos), (R.atan, C.atan), (R.exp, C.exp), (R.ln, C.ln), (R.log10, C.log10),
                        (R.sinh, C.sinh), (R.cosh, C.cosh), (R.tanh, C.tanh)]
             andalso List.all (fn p => T.sameReal (R.atan2 p, C.atan2 p) andalso T.sameReal (R.pow p, C.pow p))
                       [(1.0, 2.0), (~1.5, 0.5), (2.0, ~3.0), (0.0, ~0.0), (Real.posInf, 1.0)])

  (* with the type made transparent, as the page has it *)
  structure W : SPEC_MATH where type real = Real.real = Math
  val () = T.check ("Math:MATH/where-type-real", fn () => Real.== (W.sqrt 9.0, 3.0))
end
