structure NeedMath=BenchGamtebMathFn(BenchNeed)
structure StrictMath=BenchGamtebMathFn(BenchStrict)
structure Probe=struct
 fun show label x=print(label^" "^Real.fmt(StringCvt.GEN(SOME 17))x^"\n")
 fun plain(e:real,r:real)=
   let val a=1.0/e val b=2.0*e+1.0 val c=1.0/b val d=Math.ln b
       val f=2.0*e*(1.0+e)*c*c+4.0*a+(1.0-2.0*a*(1.0+a))*d
       val aa=1.65898+a*(0.62537*a-1.00796) val bb=aa/f
       val cc=(d-1.20397)/(1.0-bb)
   in show "ln5" d;show "b-prime" bb;show "c-prime" cc;
      0.3*Math.exp(cc*(bb-r))*e end
 val e=valOf(Real.fromString "2.0")
 val r=valOf(Real.fromString "0.999")
 val expected=valOf(Real.fromString "0.40074615290971516")
 val _=show "r-parsed" r
 val _=show "expected" expected
 val _=show "plain" (plain(e,r))
 val _=show "Need" (BenchNeed.force(NeedMath.klein(NeedMath.literal e)(NeedMath.literal r)))
 val _=show "Strict" (BenchStrict.force(StrictMath.klein(StrictMath.literal e)(StrictMath.literal r)))
 val text="-6.907755278982137"
 val _=show "scanner-negative" (valOf(Real.fromString text))
 val _=show "ln-.001" (Math.ln 0.001)
 val _=T.check("probe/completed",fn()=>true)
end
