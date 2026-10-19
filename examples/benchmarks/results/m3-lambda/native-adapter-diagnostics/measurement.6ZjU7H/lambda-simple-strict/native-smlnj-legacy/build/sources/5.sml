functor BenchLambdaDriverFn(K:sig val evaluate:string->int->string end) =
struct
  fun run style[iterationText,sizeText]=
    let val iterations=BenchInput.between(0,10000)(BenchInput.integer iterationText)
        val n=BenchInput.between(0,20000)(BenchInput.integer sizeText)
        val total=n*(n+1)div 2
        val wanted=if style="simple"then"Con "^Int.toString total^"\n"
          else if style="monad"then Int.toString total^"  []\n"
          else raise Fail "lambda expects simple or monad interpreter"
        fun loop 0 checked=Int.toString iterations^":"^Int.toString checked
          |loop left checked=
            let val actual=K.evaluate style n
            in if actual=wanted then loop(left-1)(checked+String.size actual)
               else raise Fail "incorrect result: lambda interpreter transcript"end
    in loop iterations 0 end
    |run _ _=raise Fail "lambda expects repetitions and summation bound"
end
