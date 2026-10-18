structure Benchmark=struct
 val name="happy-lazy"
 structure Kernel=BenchHappyFn(BenchNeed)
 structure Check=BenchHappyCheckFn(Kernel)
 val run=Check.run
end
