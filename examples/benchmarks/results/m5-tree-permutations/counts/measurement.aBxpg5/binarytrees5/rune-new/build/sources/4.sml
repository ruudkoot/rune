structure Benchmark =
struct
 val name="binarytrees5"
 fun run[size,path]=
   let val n=BenchInput.between(0,21)(BenchInput.integer size)
       val input=TextIO.openIn path
       val expected=(TextIO.inputAll input handle e=>(TextIO.closeIn input;raise e))
       val _=TextIO.closeIn input
       val _=BenchBinaryTrees5.checkOutput n expected
   in Int.toString(Int.max(6,n))^":checked"end
   | run _=raise Fail "binarytrees5 expects depth expected-output"
end
