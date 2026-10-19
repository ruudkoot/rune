structure Benchmark=struct
 val name="fem-strict"
 structure Kernel=BenchFemFn(val strict=true)
 structure Check=BenchFemCheckFn(Kernel)
 val run=Check.run
end
