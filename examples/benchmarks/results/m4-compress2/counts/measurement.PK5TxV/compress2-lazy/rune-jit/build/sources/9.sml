structure Benchmark =
struct
 val name="compress2-lazy"
 structure Codec=BenchCompress2Fn(BenchNeed)
 structure Driver=BenchCompressDriverFn(Codec)
 val run=Driver.run
end
