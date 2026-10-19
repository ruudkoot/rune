structure Benchmark=struct
 val name="fluid-lazy"
 structure Kernel=BenchFluidFn(BenchNeed)
 structure Check=BenchFluidCheckFn(Kernel)
 val run=Check.run
end
