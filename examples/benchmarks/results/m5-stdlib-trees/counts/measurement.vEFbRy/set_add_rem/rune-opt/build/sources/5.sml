structure Benchmark=struct
 val name="set_add_rem"
 structure Program=BenchStdlibTreePrograms
 fun run[countText]=let val count=BenchInput.between(0,50000000)(BenchInput.integer countText)
 in Program.setRun name count end
 |run _=raise Fail"expected source iteration count"
end
