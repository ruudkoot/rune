structure Benchmark=struct
 val name="parser-lazy"
 structure Kernel=BenchNofibParserFn(BenchNeed)
 structure Check=BenchNofibParserCheckFn(Kernel)
 val run=Check.run
end
