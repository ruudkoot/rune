structure Benchmark=struct
 val name="fulsom-lazy"
 structure Kernel=BenchFulsomFn(BenchNeed)
 structure Check=BenchFulsomCheckFn(Kernel)
 val run=Check.runRaw
end
