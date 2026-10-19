structure Benchmark=struct val name="tak-nofib-strict"
 fun tak(x,y,z)=if not(y<x)then z else tak(tak(x-1,y,z),tak(y-1,z,x),tak(z-1,x,y))
 fun run[x,y,z]=Int.toString(tak(BenchInput.between(0,40)(BenchInput.integer x),BenchInput.between(0,40)(BenchInput.integer y),BenchInput.between(0,40)(BenchInput.integer z)))|run _=raise Fail "tak expects x y z"end
