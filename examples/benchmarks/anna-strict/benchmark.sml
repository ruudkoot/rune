structure Benchmark=struct
 val name="anna-strict"
 structure Kernel=BenchNofibAnnaFn(BenchStrict)
 structure Check=BenchNofibAnnaCheckFn(Kernel)
 val run=Check.run
end
