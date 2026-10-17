structure A=BenchBSPTProgramFn(BenchNeed)
structure B=BenchBSPTProgramFn(BenchStrict)
structure DA=BenchBSPTDriverFn(A)
structure DB=BenchBSPTDriverFn(B)
val base="tests/out/benchmarks/bspt-originals/"
val args=["25000",base^"source/bspt.stdin",base^"batch.render"]
val _=case CommandLine.arguments()of["lazy"]=>print(DA.run args^"\n")
 |["strict"]=>print(DB.run args^"\n")|_=>raise Fail "pilot expects policy"
