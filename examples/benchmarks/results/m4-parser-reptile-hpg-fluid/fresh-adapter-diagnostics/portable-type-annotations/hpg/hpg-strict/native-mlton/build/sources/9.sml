structure Benchmark=struct
 val name="hpg-strict"
 structure Kernel=BenchHpgFn(BenchStrict)
 structure Check=BenchHpgCheckFn(Kernel)
 val run=Check.run
end
