structure Benchmark=struct
 val name="string_equal"
 structure P=BenchStdlibTextPrograms
 fun run[countText]=let val count=BenchInput.between(0,100)(BenchInput.integer countText)
 in P.runString name count end
 |run _=raise Fail"expected source iteration count"
end
