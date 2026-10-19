structure Benchmark =
struct
 val name="fannkuchredux"
 fun run[size,path]=
   let val n=BenchInput.between(3,12)(BenchInput.integer size)
       val input=TextIO.openIn path
       val expected=(TextIO.inputAll input handle e=>(TextIO.closeIn input;raise e))
       val _=TextIO.closeIn input
       val _=BenchFannkuchRedux.checkOutput n expected
   in Int.toString n^":checked"end
   | run _=raise Fail "fannkuchredux expects permutation-size expected-output"
end
