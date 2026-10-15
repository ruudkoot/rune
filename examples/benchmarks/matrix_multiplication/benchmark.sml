structure Benchmark =
struct
 structure K = BenchOCamlArrayKernels
 structure C = BenchOCamlArrayChecks
 structure R = BenchOCamlRandom
 val name = "matrix_multiplication"
 fun run [size,path] =
   let val n=BenchInput.between(1,1024)(BenchInput.integer size)
   in C.multiply n path end
   | run _ = raise Fail "invalid array workload arguments"
end
