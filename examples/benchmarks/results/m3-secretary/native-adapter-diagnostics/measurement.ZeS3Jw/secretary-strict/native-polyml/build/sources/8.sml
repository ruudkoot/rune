structure Benchmark =
struct
  val name = "secretary-strict"
  structure Kernel = struct val run = BenchSecretary.strict end
  structure Driver = BenchSecretaryDriverFn (Kernel)
  val run = Driver.run
end
