structure Benchmark=struct
 val name="rewrite-nofib-lazy"
 structure Program=BenchRewriteFn(val eagerChildren=false)
 structure Driver=BenchRewriteDriverFn(Program)
 val run=Driver.run
end
