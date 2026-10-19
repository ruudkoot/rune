structure BenchWheelCheck =
struct
  fun range (start:IntInf.int, stop, step) = BenchLazy.delay(fn()=>
    if start>stop() then BenchStream.Nil else BenchStream.Cons(BenchLazy.delay(fn()=>start),
      range(IntInf.+(start,step),stop,step)))
  fun run calculate [size,reps,expected] =
    let val n=BenchInput.between(0,40000)(BenchInput.integer size)
        val count=BenchInput.between(1,100)(BenchInput.integer reps)
        val want=BenchInput.integer expected
        fun one()=let val got=calculate n in if got=IntInf.fromInt want then IntInf.toInt got
          else raise Fail "wheel prime differs"end
    in IntInf.toString(BenchInput.repeat count one)end
    |run _ _=raise Fail "wheel sieve expects prime-index repetitions expected-prime"
end
