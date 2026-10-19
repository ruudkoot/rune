structure K=BenchNofibParserFn(BenchNeed)
structure Check=BenchNofibParserCheckFn(K)
val _=if Check.run["500","tests/out/benchmarks/pinned/nofib/real/parser/parser.faststdin","3D994E1AE49F5B1D"]="500"then print"PASS original 500-parse smoke loop\n"
 else raise Fail"source loop"
