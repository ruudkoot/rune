structure Benchmark=struct
 val name="symalg-lazy"
 structure Kernel=BenchSymalgFn(BenchNeed)
 structure Check=BenchSymalgCheckFn(Kernel)
 val run=Check.run
end
