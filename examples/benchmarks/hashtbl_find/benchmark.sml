structure Benchmark=struct
 val name="hashtbl_find"
 fun run[countText]=let val count=BenchInput.between(0,100000)(BenchInput.integer countText)
 in BenchStdlibHashtblPrograms.run name count end
 |run _=raise Fail"expected source iteration count"
end
