structure G2Diagnostic=
struct
 fun real label value=print(label^" "^Real.fmt(StringCvt.GEN(SOME 17))value^"\n")
 val _=real"sqrt2"(Math.sqrt 2.0)
 val u=1.0/Math.sqrt 2.0
 val _=real"u"u
 val _=List.app(fn(label,value)=>real label value)
  [("p",0.3275911),("a1",0.254829592),("a2",~0.284496736),("a3",1.421413741),("a4",~1.453152027),("a5",1.061405429)]
 val _=real"exp-half"(Math.exp(~u*u))
 val _=real"erf"(BenchG2Math.erf u)
 val _=real"cdf"(BenchG2Math.gaussianP 1.0)
 val state=BenchG2Random.create()
 val _=List.app(fn _=>let val word=BenchOCamlRandom.bits state
    val _=print("bits "^Int.toString word^"\n")
    val _=(print("mod "^Int.toString(word mod 40)^"\n")handle ex=>print("mod-ex "^General.exnName ex^" "^General.exnMessage ex^"\n"))
    in()end)(List.tabulate(20,fn i=>i))
 val state=BenchG2Random.create()
 val _=List.app(fn _=>((print("integer "^Int.toString(BenchG2Random.integer state 40)^"\n"))
      handle ex=>print("integer-ex "^General.exnName ex^" "^General.exnMessage ex^"\n")))(List.tabulate(20,fn i=>i))
 val _=print"diagnostic complete\n"
end
