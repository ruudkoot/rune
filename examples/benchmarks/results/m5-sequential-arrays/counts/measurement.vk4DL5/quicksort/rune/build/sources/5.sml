structure Benchmark =
struct
 structure K = BenchOCamlArrayKernels
 structure C = BenchOCamlArrayChecks
 structure R = BenchOCamlRandom
 val name = "quicksort"
 fun run [size] =
   let val n=BenchInput.between(1,4000000)(BenchInput.integer size)
   in C.sort R.default (fn a=>K.quicksort a 0(Array.length a-1)) n end
   | run _ = raise Fail "invalid array workload arguments"
end
