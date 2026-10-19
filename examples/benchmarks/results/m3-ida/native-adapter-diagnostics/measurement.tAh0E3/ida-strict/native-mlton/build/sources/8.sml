structure Benchmark=struct
 val name="ida-strict"
 structure Program=BenchIdaFn(BenchStrict)
 structure Driver=BenchIdaDriverFn(Program)
 val run=Driver.run
end
