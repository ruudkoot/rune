structure Benchmark=struct
 val name="cacheprof-nofib-lazy"
 structure Kernel=BenchCacheprofFn(BenchNeed)
 structure Check=BenchCacheprofCheckFn(Kernel)
 val run=Check.runForced
end
