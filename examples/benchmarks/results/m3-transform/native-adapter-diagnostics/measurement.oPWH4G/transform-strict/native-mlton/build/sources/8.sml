structure Benchmark=struct
 val name="transform-strict"
 structure Kernel=BenchTransformFn(BenchStrict)
 structure Check=BenchTransformCheckFn(Kernel)
 val run=Check.run
end
