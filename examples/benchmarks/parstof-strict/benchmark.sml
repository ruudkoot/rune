structure Benchmark=struct
 val name="parstof-strict"
 structure Kernel=BenchParstofFn(BenchStrict)
 structure Check=BenchParstofCheckFn(Kernel)
 val run=Check.run
end
