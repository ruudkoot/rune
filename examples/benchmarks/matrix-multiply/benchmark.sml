structure Benchmark =
struct
  val name = "matrix-multiply"
  fun run [size] =
    let val n = BenchInput.between (1,500) (BenchInput.integer size)
        val input = Array2.array (n,n,1.0)
        val result = BenchMatrix.mult (input,input)
        val _ = Array2.app Array2.RowMajor
          (fn x => if Real.==(x,Real.fromInt n) then () else raise Fail "matrix product") result
        val ni = IntInf.fromInt n
    in IntInf.toString (IntInf.* (IntInf.* (ni,ni),ni)) end
    | run _ = raise Fail "matrix-multiply expects dimension"
end
