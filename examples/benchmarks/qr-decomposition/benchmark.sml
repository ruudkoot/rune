structure Benchmark =
struct
  val name="qr-decomposition"
  structure M=BenchMatrixFiles
  val inputs=BenchLazy.delay(fn()=>M.load "data/matrix.txt")
  fun run [size]=
    let val rows=BenchInput.between(1,219)(BenchInput.integer size)
        val input=M.prefix(BenchLazy.force inputs)rows
        val _=BenchQRCheck.run input val(_,columns)=M.size input
    in Int.toString rows^":"^Int.toString columns^":checked"end
    | run _=raise Fail "QR expects a row count"
end
