structure Benchmark=struct
 val name="fulsom-strict"
 structure Kernel=BenchFulsomFn(BenchStrict)
 structure Check=BenchFulsomCheckFn(Kernel)
 val run=Check.runRaw
end
