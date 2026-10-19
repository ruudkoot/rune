structure Benchmark=struct
 val name="hashtbl_add_sized"
 fun run[countText]=let val count=BenchInput.between(0,1000000)(BenchInput.integer countText)
 in BenchStdlibHashtblPrograms.run name count end
 |run _=raise Fail"expected source iteration count"
end
