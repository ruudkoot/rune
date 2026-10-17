functor BenchEventDriverFn(P:sig val benchmark:int->string end)=
struct
  fun read path=let val f=TextIO.openIn path val s=TextIO.inputAll f val _=TextIO.closeIn f in s end
  fun run[repetitions,finish,path]=
    let val count=BenchInput.between(1,1000000)(BenchInput.integer repetitions)
        val finish=BenchInput.between(0,500000)(BenchInput.integer finish)
        val expected=read path
        val _=if String.size expected=14 andalso String.sub(expected,13)= #"\n"then()
              else raise Fail "expected thirteen-wire state and newline"
        fun loop 0 total last=Int.toString count^" "^Int.toString total^" "^String.substring(last,0,13)
          |loop n total _=let val result=P.benchmark finish
              in if result=expected then loop(n-1)(total+String.size result)result
                 else raise Fail "incorrect result: event state"end
    in loop count 0""end
    |run _=raise Fail "expected repetitions, event horizon and state reference"
end
