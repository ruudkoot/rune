structure Benchmark =
struct
  val name = "compress-lazy"
  structure Codec = BenchCompressFn(BenchNeed)
  structure Driver = BenchCompressDriverFn(Codec)
  val run = Driver.run
end
