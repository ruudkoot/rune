structure Benchmark=struct
 val name="reptile-strict"
 structure Kernel=BenchReptileFn(BenchStrict)
 structure Check=BenchReptileCheckFn(Kernel)
 val run=Check.run
end
