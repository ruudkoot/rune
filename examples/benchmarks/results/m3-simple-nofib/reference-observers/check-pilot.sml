structure C=BenchSimpleCheckFn(val strict=false val report=false val gridMax=8)
structure P=BenchSimpleCheckFn(val strict=false val report=true val gridMax=8)
val _=print(C.run["1","tests/out/benchmarks/nofib-simple-originals/data/totals-8-1.reference"]^"\n")
val _=print(P.run["1","tests/out/benchmarks/nofib-simple-originals/data/state-8-1.reference"]^"\n")
