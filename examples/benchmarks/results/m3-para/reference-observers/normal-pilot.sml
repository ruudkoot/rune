structure A=BenchParaFn(BenchNeed)
structure B=BenchParaFn(BenchStrict)
structure DA=BenchParaDriverFn(A)
structure DB=BenchParaDriverFn(B)
val base="tests/out/benchmarks/para-originals/"
val args=["8",base^"source/runtime_files/input-data",base^"formatted.reference"]
val _=print(DA.run args^"\n")
val _=print(DB.run args^"\n")
