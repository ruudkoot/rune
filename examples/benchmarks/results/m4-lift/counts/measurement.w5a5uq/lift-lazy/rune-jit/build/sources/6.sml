structure Benchmark=struct
 val name="lift-lazy"
 structure Kernel=BenchLiftFn(val strict=false)
 structure Check=BenchLiftCheckFn(Kernel)
 val run=Check.run
end
