structure BenchExtendedGCDTests =
struct
  val tuple=BenchExtendedGCD.strict 5001 10003
  val _=T.check("gcd/bezout-and-divisibility",fn()=>(BenchExtendedGCD.consume(5001,10003,tuple);true))
  val(g,u,v)=tuple
  val _=T.check("gcd/incorrect-coefficient-rejected",fn()=>
    (BenchExtendedGCD.consume(5001,10003,(g,IntInf.+(u,1),v));false)handle Fail _=>true)
  val _=T.check("gcd/incorrect-divisor-rejected",fn()=>
    (BenchExtendedGCD.consume(6,9,(12,2,0));false)handle Fail _=>true)
  val _=T.check("gcd/zero-first",fn()=>BenchExtendedGCD.strict 0 7=(7,0,1))
end
