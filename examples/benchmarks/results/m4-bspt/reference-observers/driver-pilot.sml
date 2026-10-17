structure A=BenchBSPTProgramFn(BenchNeed)
structure B=BenchBSPTProgramFn(BenchStrict)
structure DA=BenchBSPTDriverFn(A)
structure DB=BenchBSPTDriverFn(B)
val base="tests/out/benchmarks/bspt-originals/"
val _=print(DA.run["1",base^"source/bspt.stdin",base^"batch.render"]^"\n")
val _=print(DB.run["1",base^"source/bspt.stdin",base^"batch.render"]^"\n")
val _=print(DA.run["2",base^"source/bspt.stdin",base^"batch.render"]^"\n")
