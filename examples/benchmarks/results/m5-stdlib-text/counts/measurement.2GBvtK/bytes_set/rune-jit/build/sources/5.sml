structure Benchmark=struct
 val name="bytes_set"
 structure P=BenchStdlibTextPrograms
 val input=BenchStdlibText.Bytes.ofString BenchStdlibText.text
 fun run[countText]=let val count=BenchInput.between(0,1000000)(BenchInput.integer countText)
 in P.runBytes input name count end
 |run _=raise Fail"expected source iteration count"
end
