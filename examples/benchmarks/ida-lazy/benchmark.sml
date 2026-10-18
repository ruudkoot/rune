structure Benchmark=struct
 val name="ida-lazy"
 structure Program=BenchIdaFn(BenchNeed)
 structure Driver=BenchIdaDriverFn(Program)
 val run=Driver.run
end
