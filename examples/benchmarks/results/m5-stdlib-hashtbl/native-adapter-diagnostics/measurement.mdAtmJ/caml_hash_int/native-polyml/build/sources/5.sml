structure Benchmark=struct
 val name="caml_hash_int"
 fun run[countText]=let val count=BenchInput.between(0,10000)(BenchInput.integer countText)
 in BenchStdlibHashtblPrograms.run name count end
 |run _=raise Fail"expected source iteration count"
end
