structure Kernel = BenchTak
structure Benchmark=struct val name="tak-mlkit"
fun run [sx,sy,sz,reps] = let val x=BenchInput.between(0,40)(BenchInput.integer sx) val y=BenchInput.between(0,40)(BenchInput.integer sy) val z=BenchInput.between(0,40)(BenchInput.integer sz) val r=BenchInput.between(1,10000)(BenchInput.integer reps) in IntInf.toString(BenchInput.repeat r(fn()=>Kernel.tak(x,y,z))) end | run _=raise Fail "tak expects x y z repetitions"
end
