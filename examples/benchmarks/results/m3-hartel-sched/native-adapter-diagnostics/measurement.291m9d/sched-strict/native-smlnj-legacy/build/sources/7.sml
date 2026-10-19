structure Benchmark=struct
 val name="sched-strict"
 structure Kernel=BenchSchedFn(BenchStrict)
 structure Driver=BenchSchedDriverFn(Kernel)
 val run=Driver.run
end
