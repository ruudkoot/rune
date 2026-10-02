structure Benchmark =
struct
  val name = "matrix-multiply-ramp"
  fun run [size] =
        let val n = BenchInput.between (1, 500) (BenchInput.integer size)
            val input = Array2.tabulate Array2.RowMajor (n,n,fn (r,c) => Real.fromInt (r+c))
            val result = BenchMatrix.mult (input,input)
            val ni = IntInf.fromInt n
            val s1 = IntInf.div (IntInf.* (ni,IntInf.- (ni,1)),2)
            val s2 = IntInf.div (IntInf.* (IntInf.* (ni,IntInf.- (ni,1)),IntInf.- (IntInf.* (2,ni),1)),6)
            fun expected (i,j) = IntInf.+ (IntInf.+ (IntInf.* (ni,IntInf.* (IntInf.fromInt i,IntInf.fromInt j)),
              IntInf.* (IntInf.fromInt (i+j),s1)),s2)
            fun check (i,j,sum) = if i=n then sum else if j=n then check(i+1,0,sum) else
              let val want = expected(i,j)
                  val observed = Array2.sub(result,i,j)
              in if BenchInput.closeReal(observed,Real.fromLargeInt want,0.000001,0.0) then check(i,j+1,IntInf.+(sum,want))
                 else raise Fail "matrix result" end
        in IntInf.toString(check(0,0,0)) end
    | run _ = raise Fail "matrix-multiply expects dimension"
end
