structure Benchmark=struct
 val name="cacheprof-lazy"
 structure Kernel=BenchCacheprofFn(BenchNeed)
 structure Check=BenchCacheprofCheckFn(Kernel)
 val run=Check.runRaw
end
