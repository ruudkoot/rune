structure Benchmark=struct
 val name="hashtbl_add_duplicate"
 fun run[countText]=let val count=BenchInput.between(0,500000)(BenchInput.integer countText)
 in BenchStdlibHashtblPrograms.run name count end
 |run _=raise Fail"expected source iteration count"
end
