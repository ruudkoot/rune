structure A=BenchSphereFn(BenchNeed)
structure B=BenchSphereFn(BenchStrict)
structure DA=BenchSphereDriverFn(A)
structure DB=BenchSphereDriverFn(B)
val path="tests/out/benchmarks/sphere-originals/normal.pixels"
val _=print(DA.run["100","100",path]^"\n")
val _=print(DB.run["100","100",path]^"\n")
