structure A=BenchLinearFn(BenchNeed)
structure B=BenchLinearFn(BenchStrict)
structure DA=BenchLinearDriverFn(struct type number=A.number val stats=A.stats val value=A.B.value end)
structure DB=BenchLinearDriverFn(struct type number=B.number val stats=B.stats val value=B.B.value end)
val base="tests/out/benchmarks/linear-originals/"
val _=case CommandLine.arguments()of[policy,mode]=>
 let val args=if mode="gc"then["1","14","50",base^"gc-normal.metrics"]
       else["200","4","10",base^"real-normal.metrics"]
 in print((if policy="lazy"then DA.run mode args else DB.run mode args)^"\n")end
 |_=>raise Fail "pilot expects policy and mode"
