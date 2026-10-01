structure VliwBenchTests =
struct
  fun same(a,b)=VliwCheck.normalized a=VliwCheck.normalized b
  val _=T.check("benchmark.vliw/real-format",fn()=>same(["GETREAL","r/R1",":=","3"],["GETREAL","r/R1",":=","3.0"]))
  val _=T.check("benchmark.vliw/real-exponent",fn()=>same(["GETREAL","r/R1",":=","3E0"],["GETREAL","r/R1",":=","3.000"]))
  val _=T.check("benchmark.vliw/signed-zero",fn()=>not(same(["GETREAL","r/R1",":=","0.0"],["GETREAL","r/R1",":=","~0.0"])))
  val _=T.check("benchmark.vliw/value-change",fn()=>not(same(["GETREAL","r/R1",":=","3"],["GETREAL","r/R1",":=","4"])))
  val _=T.check("benchmark.vliw/registers",fn()=>not(same(["MOVE","0/R0"],["MOVE","0/R1"])))
  val _=T.check("benchmark.vliw/invalid-literal",fn()=>
    (VliwCheck.normalized["GETREAL","r/R1",":=","3/R1"];false) handle Fail _=>true)
end
