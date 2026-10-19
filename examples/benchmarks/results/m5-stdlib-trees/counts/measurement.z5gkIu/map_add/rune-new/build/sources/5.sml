structure Benchmark=struct
 val name="map_add"
 structure Program=BenchStdlibTreePrograms
 val entries=Program.mapEntries 10000
 val baseline=Program.denseMapEntries entries
 fun run[countText]=let val count=BenchInput.between(0,1000000)(BenchInput.integer countText)
 in Program.mapRun name baseline count end
 |run _=raise Fail"expected source iteration count"
end
