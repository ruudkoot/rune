structure A=BenchLinearFn(BenchNeed)
structure B=BenchLinearFn(BenchStrict)
structure DA=BenchLinearDriverFn(struct type number=A.number val stats=A.stats val value=A.B.value end)
structure DB=BenchLinearDriverFn(struct type number=B.number val stats=B.stats val value=B.B.value end)
val path="tests/out/benchmarks/linear-originals/gc-smoke.metrics"
val _=print(DA.run"gc"["1","2","50",path]^"\n")
val _=print(DB.run"real"["1","2","10",path]^"\n")
