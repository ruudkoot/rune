structure Benchmark=struct
 val name="str_string_match"
 fun run[countText]=let val count=BenchInput.between(0,200000)(BenchInput.integer countText)
 in BenchStdlibStr.run name count end
 |run _=raise Fail"expected source iteration count"
end
