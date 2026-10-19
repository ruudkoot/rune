structure Benchmark=struct
 val name="str_global_replace"
 fun run[countText]=let val count=BenchInput.between(0,100000)(BenchInput.integer countText)
 in BenchStdlibStr.run name count end
 |run _=raise Fail"expected source iteration count"
end
