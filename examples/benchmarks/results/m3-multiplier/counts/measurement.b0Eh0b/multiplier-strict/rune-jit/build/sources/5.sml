functor BenchMultiplierDriverFn(P:sig val trace:int->int->char BenchStream.stream val readyCount:int->int->int end)=
struct
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun consume expected output=
    let fun loop index xs=case BenchLazy.force xs of BenchStream.Nil=>
            if index=String.size expected then index else raise Fail "incorrect result: short multiplier trace"
          |BenchStream.Cons(c,rest)=>if index<String.size expected andalso BenchLazy.force c=String.sub(expected,index)
            then loop(index+1)rest else raise Fail "incorrect result: multiplier trace character"
    in loop 0 output end
  fun run[width,cycles,path]=
    let val width=BenchInput.between(1,1024)(BenchInput.integer width)
        val cycles=BenchInput.between(0,2000)(BenchInput.integer cycles)
        val expected=read path
        val count=consume expected(P.trace width cycles)
    in Int.toString width^" "^Int.toString cycles^" "^Int.toString count end
    |run _=raise Fail "expected bit width, clock cycles and trace reference"
  fun runCount[width,cycles,path]=
    let val width=BenchInput.between(1,1024)(BenchInput.integer width)
        val cycles=BenchInput.between(0,2000)(BenchInput.integer cycles)
        val count=P.readyCount width cycles
    in if Int.toString count^"\n"=read path
       then Int.toString width^" "^Int.toString cycles^" "^Int.toString count
       else raise Fail "incorrect result: multiplier ready count"end
    |runCount _=raise Fail "expected bit width, clock cycles and ready-count reference"

end
