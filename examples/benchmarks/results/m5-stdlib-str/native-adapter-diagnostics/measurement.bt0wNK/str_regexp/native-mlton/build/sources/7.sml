structure Benchmark=struct
 val name="str_regexp"
 fun run[countText]=let val count=BenchInput.between(0,20000)(BenchInput.integer countText)
 in BenchStdlibStr.run name count end
 |run _=raise Fail"expected source iteration count"
end
