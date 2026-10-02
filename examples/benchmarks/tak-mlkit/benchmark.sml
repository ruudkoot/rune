structure Kernel = struct
fun tak (x,y,z) =
   if not (y < x)
      then z
   else tak (tak (x - 1, y, z),
             tak (y - 1, z, x),
             tak (z - 1, x, y))


end
structure Benchmark=struct val name="tak-mlkit"
fun run [sx,sy,sz,reps] = let val x=BenchInput.between(0,40)(BenchInput.integer sx) val y=BenchInput.between(0,40)(BenchInput.integer sy) val z=BenchInput.between(0,40)(BenchInput.integer sz) val r=BenchInput.between(1,10000)(BenchInput.integer reps) in IntInf.toString(BenchInput.repeat r(fn()=>Kernel.tak(x,y,z))) end | run _=raise Fail "tak expects x y z repetitions"
end
