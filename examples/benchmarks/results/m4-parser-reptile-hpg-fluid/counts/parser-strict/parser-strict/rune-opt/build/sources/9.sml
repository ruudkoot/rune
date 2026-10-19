structure Benchmark=struct
 val name="parser-strict"
 structure Kernel=BenchNofibParserFn(BenchStrict)
 structure Check=BenchNofibParserCheckFn(Kernel)
 val run=Check.run
end
