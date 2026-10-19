structure Benchmark =
struct
  val name = "compress-strict"
  structure Codec = BenchCompressFn(BenchStrict)
  structure Driver = BenchCompressDriverFn(Codec)
  val run = Driver.run
end
