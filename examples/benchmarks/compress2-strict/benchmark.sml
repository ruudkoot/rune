structure Benchmark =
struct
 val name="compress2-strict"
 structure Codec=BenchCompress2Fn(BenchStrict)
 structure Driver=BenchCompressDriverFn(Codec)
 val run=Driver.run
end
