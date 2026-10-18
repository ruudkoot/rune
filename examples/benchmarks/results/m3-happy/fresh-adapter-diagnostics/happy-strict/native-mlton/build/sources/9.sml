structure Benchmark=struct
 val name="happy-strict"
 structure Kernel=BenchHappyFn(BenchStrict)
 structure Check=BenchHappyCheckFn(Kernel)
 val run=Check.run
end
