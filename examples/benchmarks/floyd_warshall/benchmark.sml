structure Benchmark =
struct
 structure K = BenchOCamlArrayKernels
 structure C = BenchOCamlArrayChecks
 structure R = BenchOCamlRandom
 val name = "floyd_warshall"
 fun run [size,path] =
   let val n=BenchInput.between(1,512)(BenchInput.integer size)
   in C.floyd n path end
   | run _ = raise Fail "invalid array workload arguments"
end
