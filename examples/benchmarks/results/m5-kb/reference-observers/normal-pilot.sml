structure A=BenchSandmarkKBCompletionFn(BenchSandmarkKBRaise)
structure B=BenchSandmarkKBCompletionFn(BenchSandmarkKBOption)
structure DA=BenchSandmarkKBDriverFn(A)
structure DB=BenchSandmarkKBDriverFn(B)
val path="tests/out/benchmarks/kb-sandmark-originals/kb.rules"
val _=print(DA.run["100",path]^"\n")
val _=print(DB.run["100",path]^"\n")
