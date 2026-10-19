structure Benchmark=struct
 val name="veritas-strict"
 structure Kernel=BenchNofibVeritasFn(BenchStrict)
 structure Check=BenchNofibVeritasCheckFn(Kernel)
 val run=Check.run
end
