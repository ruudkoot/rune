structure Benchmark=struct
 val name="fluid-strict"
 structure Kernel=BenchFluidFn(BenchStrict)
 structure Check=BenchFluidCheckFn(Kernel)
 val run=Check.run
end
