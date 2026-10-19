structure Benchmark=struct
 val name="fulsom-nofib-lazy"
 structure Kernel=BenchFulsomFn(BenchNeed)
 structure Check=BenchFulsomCheckFn(Kernel)
 val run=Check.runHashed
end
