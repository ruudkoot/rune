structure Benchmark=struct
 val name="solid-lazy"
 structure Kernel=BenchSolidFn(BenchNeed)
 structure Check=BenchSolidCheckFn(Kernel)
 val run=Check.run
end
