structure Benchmark=struct
 val name="rewrite-nofib-strict"
 structure Program=BenchRewriteFn(val eagerChildren=true)
 structure Driver=BenchRewriteDriverFn(Program)
 val run=Driver.run
end
