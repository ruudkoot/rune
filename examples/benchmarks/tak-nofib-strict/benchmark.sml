structure Benchmark=struct val name="tak-nofib-strict"
 fun run[x,y,z]=Int.toString(BenchTak.tak(BenchInput.between(0,40)(BenchInput.integer x),BenchInput.between(0,40)(BenchInput.integer y),BenchInput.between(0,40)(BenchInput.integer z)))|run _=raise Fail "tak expects x y z"end
