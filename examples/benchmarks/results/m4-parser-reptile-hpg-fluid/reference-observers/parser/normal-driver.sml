structure K=BenchNofibParserFn(BenchNeed)
structure Check=BenchNofibParserCheckFn(K)
val _=if Check.run["500","tests/out/benchmarks/pinned/nofib/real/parser/parser.stdin","FD8F9F553C360241"]="500"then print"PASS original 500-parse normal loop\n"
 else raise Fail"source normal loop"
