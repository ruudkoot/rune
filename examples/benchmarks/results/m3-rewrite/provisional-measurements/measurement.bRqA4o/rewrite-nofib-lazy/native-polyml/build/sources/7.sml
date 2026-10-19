functor BenchRewriteDriverFn(B:sig val calculate:int->(string->unit)option->bool end)=
struct
  fun calculate count expected=
    let val checked=ref 0
        fun observe term=if term=expected then checked:= !checked+1
          else raise Fail "incorrect result: rewritten term"
        val result=B.calculate count(SOME observe)
    in if result andalso !checked=Int.max(0,count)then "True"
       else raise Fail "incorrect result: rewrite result or count"end
  fun run[count]=calculate(BenchInput.between(0,1200000)(BenchInput.integer count))"*(I(b),I(a))"
    |run _=raise Fail "expected rewrite query count"
end
