structure Benchmark =
struct
 val name="cryptarithm2-strict"
 structure Kernel=BenchCryptarithmFn(BenchStrict)
 fun run[count,path]=
   let val n=BenchInput.between(0,1500)(BenchInput.integer count)
       val input=TextIO.openIn path
       val expected=(TextIO.inputAll input handle e=>(TextIO.closeIn input;raise e))
       val _=TextIO.closeIn input
       fun loop i bytes=if i>n then Int.toString n^":"^Int.toString bytes else
         let val words=["THIRTY","TWELVE","TWELVE","TWELVE","TWELVE","TWELVE"^(if i>999999 then "1"else "")]
             val actual=Kernel.puzzle words "NINETY"
             val _=if actual=expected then ()else raise Fail "cryptarithm mapping differs"
         in loop(i+1)(bytes+String.size actual)end
   in loop 1 0 end
   | run _=raise Fail "cryptarithm2 expects repetitions expected-mapping"
end
