structure Benchmark=struct
 val name="string_split_on_char"
 structure P=BenchStdlibTextPrograms
 fun run[countText]=let val count=BenchInput.between(0,50000)(BenchInput.integer countText)
 in P.runString name count end
 |run _=raise Fail"expected source iteration count"
end
