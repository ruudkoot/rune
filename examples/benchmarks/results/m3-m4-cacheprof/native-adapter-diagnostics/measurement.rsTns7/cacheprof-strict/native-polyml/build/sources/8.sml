structure Benchmark=struct
 val name="cacheprof-strict"
 structure Kernel=BenchCacheprofFn(BenchStrict)
 structure Check=BenchCacheprofCheckFn(Kernel)
 val run=Check.runRaw
end
