structure Benchmark =
struct
 val name="cryptarithm1-lazy"
 structure Kernel=BenchCryptarithmPermutationFn(BenchNeed)
 fun run[count]=
   let val n=BenchInput.between(1,15)(BenchInput.integer count)
       val expected="[[1,9,4,2,5,3,0,7,6,8]]\n"
       fun loop i bytes=if i>n then Int.toString n^":"^Int.toString bytes else
         let val actual=Kernel.run i
         in if actual=expected then loop(i+1)(bytes+String.size actual)
            else raise Fail "cryptarithm1 exhaustive result differs"end
   in loop 1 0 end
   | run _=raise Fail "cryptarithm1 expects repetitions"
end
