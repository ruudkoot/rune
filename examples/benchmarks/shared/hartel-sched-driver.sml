functor BenchSchedDriverFn(K:sig val calculate:int->int->int end)=
struct
 fun expected size=case size of 1=>10|3=>60|7=>148|10=>190|11=>218|12=>228|14=>267|_=>0
 fun run[repetitionsText,sizeText]=
   let val repetitions=BenchInput.between(0,5000)(BenchInput.integer repetitionsText)
       val size=BenchInput.between(0,14)(BenchInput.integer sizeText)
       val threshold=if size<=3 then 0 else size-3
       fun loop 0 count total=(count,total)
         |loop remaining count total=
           let val actual=K.calculate threshold size
               val _=if actual=expected size then()else raise Fail"incorrect result: scheduler minimum"
           in loop(remaining-1)(count+1)(IntInf.+(total,IntInf.fromInt actual))end
       val(count,total)=loop repetitions 0(IntInf.fromInt 0)
   in Int.toString count^":"^IntInf.toString total end
 |run _=raise Fail"expected repetition count and original job-graph selector"
end
