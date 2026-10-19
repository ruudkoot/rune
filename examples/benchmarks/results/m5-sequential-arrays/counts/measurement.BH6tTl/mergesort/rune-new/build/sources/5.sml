structure Benchmark =
struct
 structure K = BenchOCamlArrayKernels
 structure C = BenchOCamlArrayChecks
 structure R = BenchOCamlRandom
 val name = "mergesort"
 fun run [size] =
   let val n=BenchInput.between(1,67108864)(BenchInput.integer size)
   in C.sort R.seed42 K.mergesort n end
   | run _ = raise Fail "invalid array workload arguments"
end
