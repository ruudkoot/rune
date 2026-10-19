structure Benchmark =
struct
  val name = "rsa-lazy"
  structure Cipher = BenchRsaFn(BenchNeed)
  structure Driver = BenchRsaDriverFn(Cipher)
  val run = Driver.run
end
