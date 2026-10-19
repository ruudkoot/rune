structure Benchmark=struct
 val name="parstof-lazy"
 structure Kernel=BenchParstofFn(BenchNeed)
 structure Check=BenchParstofCheckFn(Kernel)
 val run=Check.run
end
