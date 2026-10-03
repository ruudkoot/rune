structure Benchmark =
struct
  val name = "rsa-strict"
  structure Cipher = BenchRsaFn(BenchStrict)
  structure Driver = BenchRsaDriverFn(Cipher)
  val run = Driver.run
end
