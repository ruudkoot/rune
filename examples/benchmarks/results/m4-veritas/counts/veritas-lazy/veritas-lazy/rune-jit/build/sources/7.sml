structure Benchmark=struct
 val name="veritas-lazy"
 structure Kernel=BenchNofibVeritasFn(BenchNeed)
 structure Check=BenchNofibVeritasCheckFn(Kernel)
 val run=Check.run
end
