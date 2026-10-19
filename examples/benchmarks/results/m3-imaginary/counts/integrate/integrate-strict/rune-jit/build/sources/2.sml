(* Nine-point nested trapezoidal integrations, in upstream summation order. *)
structure BenchIntegrate =
struct
  fun integrate1D l u f =
    let val d=(u-l)/8.0
        val values = [f l*0.5, f(l+d), f(l+2.0*d), f(l+3.0*d),
          f(l+4.0*d), f(u-3.0*d), f(u-2.0*d), f(u-d), f u*0.5]
    in d * List.foldl (fn (x,a) => a+x) 0.0 values end
  fun zark u v = integrate1D 0.0 v (fn y => integrate1D 0.0 u (fn x => x*y))
  fun fourth (x:real) = let val square=x*x in square*square end
  fun checked n (result, rtotal, itotal) reference =
    let val f=TextIO.openIn reference
        val fields=String.tokens Char.isSpace (TextIO.inputAll f)
        val _=TextIO.closeIn f
        val (target,bound)=case List.map Real.fromString fields of
          [SOME t,SOME b] => (t,b) | _ => raise Fail "integration reference"
        val k=IntInf.fromInt n
        val k1=IntInf.+(k,1)
        val k2=IntInf.+(IntInf.*(2,k),1)
        val p=IntInf.-(IntInf.+(IntInf.*(3,IntInf.*(k,k)),IntInf.*(3,k)),1)
        val exact=IntInf.div(IntInf.*(IntInf.*(IntInf.*(k,k1),k2),p),30)
        val total=Real.fromLargeInt exact
        val u=2.220446049250313E~16
        val gamma=(Real.fromInt n+200.0)*u/(1.0-(Real.fromInt n+200.0)*u)
        val totalBound=2.0*gamma*Real.abs total
    in if Real.isFinite target andalso Real.isFinite bound andalso bound>=0.0
      andalso Real.isFinite result andalso result>=0.0 andalso Real.abs(result-target)<=bound
      andalso Real.isFinite rtotal andalso Real.isFinite itotal
      andalso Real.abs(rtotal-total)<=totalBound andalso Real.abs(itotal-total)<=totalBound
      then Int.toString n else raise Fail "integration accumulated error differs" end
end
