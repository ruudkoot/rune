structure Benchmark =
struct
  val name="crout-decomposition"
  structure M=BenchMatrixFiles
  val inputs=BenchLazy.delay(fn()=>M.load "data/matrix.txt")
  fun run [size,path]=
    let val rows=BenchInput.between(1,2730)(BenchInput.integer size)
        val input=M.prefix(BenchLazy.force inputs)rows
        val expected=M.load path val result=BenchCrout.main input
        val _=M.check 2.0E~9 2.0E~9 expected result val(_,columns)=M.size result
    in Int.toString rows^":"^Int.toString columns^":checked"end
    | run _=raise Fail "Crout expects a row count and source-result reference"
end
