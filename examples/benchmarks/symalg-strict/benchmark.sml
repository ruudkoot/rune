structure Benchmark=struct
 val name="symalg-strict"
 structure Kernel=BenchSymalgFn(BenchStrict)
 structure Check=BenchSymalgCheckFn(Kernel)
 val run=Check.run
end
