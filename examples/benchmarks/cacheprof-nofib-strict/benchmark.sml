structure Benchmark=struct
 val name="cacheprof-nofib-strict"
 structure Kernel=BenchCacheprofFn(BenchStrict)
 structure Check=BenchCacheprofCheckFn(Kernel)
 val run=Check.runForced
end
