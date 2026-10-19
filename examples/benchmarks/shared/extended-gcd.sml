structure BenchExtendedGCD =
struct
  fun strict x y=
    let fun loop((a,b,c),(u,v,w))=if w=0 then(c,a,b)else
          let val(q,r)=IntInf.quotRem(c,w)
          in loop((u,v,w),(IntInf.-(a,IntInf.*(q,u)),IntInf.-(b,IntInf.*(q,v)),r))end
    in if x=0 then(y,0,1)else loop((1,0,x),(0,1,y))end
  fun consume(x,y,result as(g,u,v))=
    if g>0 andalso IntInf.+(IntInf.*(u,x),IntInf.*(v,y))=g
      andalso IntInf.rem(x,g)=0 andalso IntInf.rem(y,g)=0
    then IntInf.abs(IntInf.+(IntInf.+(g,u),v))else raise Fail "extended GCD identity differs"
  fun run calculate[size,expected]=
    let val d=BenchInput.between(0,9000)(BenchInput.integer size)
        val want=case IntInf.fromString expected of SOME n=>n|NONE=>raise Fail "GCD expected result"
        val got=calculate d
    in if got=want then IntInf.toString got else raise Fail "extended GCD maximum differs"end
    |run _ _=raise Fail "gcd expects square-range expected-maximum"
end
