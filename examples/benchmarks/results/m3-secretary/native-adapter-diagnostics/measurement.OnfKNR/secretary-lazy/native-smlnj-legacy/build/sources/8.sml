structure Benchmark =
struct
  val name = "secretary-lazy"
  structure Kernel = struct val run = BenchSecretary.lazy end
  structure Driver = BenchSecretaryDriverFn (Kernel)
  val run = Driver.run
end
