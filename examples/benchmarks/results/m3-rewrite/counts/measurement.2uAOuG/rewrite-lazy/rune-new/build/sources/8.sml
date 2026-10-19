structure Benchmark=struct
 val name="rewrite-lazy"
 structure Program=BenchRewriteFn(val eagerChildren=false)
 structure Driver=BenchRewriteDriverFn(Program)
 val run=Driver.run
end
