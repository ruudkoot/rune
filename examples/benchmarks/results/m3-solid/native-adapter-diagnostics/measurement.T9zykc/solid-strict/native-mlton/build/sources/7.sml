structure Benchmark=struct
 val name="solid-strict"
 structure Kernel=BenchSolidFn(BenchStrict)
 structure Check=BenchSolidCheckFn(Kernel)
 val run=Check.run
end
