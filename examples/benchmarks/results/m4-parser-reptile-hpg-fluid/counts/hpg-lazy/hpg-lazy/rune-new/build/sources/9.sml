structure Benchmark=struct
 val name="hpg-lazy"
 structure Kernel=BenchHpgFn(BenchNeed)
 structure Check=BenchHpgCheckFn(Kernel)
 val run=Check.run
end
