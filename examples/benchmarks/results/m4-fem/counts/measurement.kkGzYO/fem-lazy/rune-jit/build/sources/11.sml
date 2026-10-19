structure Benchmark=struct
 val name="fem-lazy"
 structure Kernel=BenchFemFn(val strict=false)
 structure Check=BenchFemCheckFn(Kernel)
 val run=Check.run
end
