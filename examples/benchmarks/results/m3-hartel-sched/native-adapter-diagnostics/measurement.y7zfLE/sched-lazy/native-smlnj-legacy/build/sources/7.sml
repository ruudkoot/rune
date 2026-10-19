structure Benchmark=struct
 val name="sched-lazy"
 structure Kernel=BenchSchedFn(BenchNeed)
 structure Driver=BenchSchedDriverFn(Kernel)
 val run=Driver.run
end
