structure Benchmark=struct
 val name="transform-lazy"
 structure Kernel=BenchTransformFn(BenchNeed)
 structure Check=BenchTransformCheckFn(Kernel)
 val run=Check.run
end
