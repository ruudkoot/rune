structure Benchmark=struct
 val name="fulsom-nofib-strict"
 structure Kernel=BenchFulsomFn(BenchStrict)
 structure Check=BenchFulsomCheckFn(Kernel)
 val run=Check.runHashed
end
