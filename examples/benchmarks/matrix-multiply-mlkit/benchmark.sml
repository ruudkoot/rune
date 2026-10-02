structure Benchmark=struct
val name="matrix-multiply-mlkit"
fun run [size,reps] = let val n=BenchInput.between(1,500)(BenchInput.integer size) val r=BenchInput.between(1,1000)(BenchInput.integer reps)
fun one()=let val input=Array2.array(n,n,1.0) val result=BenchMatrix.mult(input,input)
val _=Array2.app Array2.RowMajor (fn x=>if Real.==(x,Real.fromInt n) then () else raise Fail "matrix product") result
in IntInf.*(IntInf.*(IntInf.fromInt n,IntInf.fromInt n),IntInf.fromInt n) end
fun loop(0,sum)=sum | loop(k,sum)=loop(k-1,IntInf.+(sum,one()))
in IntInf.toString(loop(r,0)) end | run _=raise Fail "matrix expects dimension repetitions" end
