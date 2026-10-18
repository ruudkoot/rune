structure Benchmark=struct
 val name="lift-strict"
 structure Kernel=BenchLiftFn(val strict=true)
 structure Check=BenchLiftCheckFn(Kernel)
 val run=Check.run
end
