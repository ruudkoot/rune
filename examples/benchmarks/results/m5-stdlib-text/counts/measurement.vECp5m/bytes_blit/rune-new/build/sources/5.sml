structure Benchmark=struct
 val name="bytes_blit"
 structure P=BenchStdlibTextPrograms
 val input=BenchStdlibText.Bytes.ofString BenchStdlibText.text
 fun run[countText]=let val count=BenchInput.between(0,20000)(BenchInput.integer countText)
 in P.runBytes input name count end
 |run _=raise Fail"expected source iteration count"
end
