structure Benchmark=struct
 val name="anna-lazy"
 structure Kernel=BenchNofibAnnaFn(BenchNeed)
 structure Check=BenchNofibAnnaCheckFn(Kernel)
 val run=Check.run
end
