structure Benchmark=struct
 val name="reptile-lazy"
 structure Kernel=BenchReptileFn(BenchNeed)
 structure Check=BenchReptileCheckFn(Kernel)
 val run=Check.run
end
