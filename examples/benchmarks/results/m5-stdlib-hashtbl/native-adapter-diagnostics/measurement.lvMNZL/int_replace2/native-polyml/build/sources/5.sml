structure Benchmark=struct
 val name="int_replace2"
 fun run[countText]=let val count=BenchInput.between(0,1000)(BenchInput.integer countText)
 in BenchStdlibHashtblPrograms.run name count end
 |run _=raise Fail"expected source iteration count"
end
