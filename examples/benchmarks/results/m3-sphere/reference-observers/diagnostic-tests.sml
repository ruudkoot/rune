structure K=BenchSphereFn(BenchNeed)
structure Driver=BenchSphereDiagnosticDriverFn(K)
val _=T.check("sphere/diagnostic/normal-lazy",fn()=>Driver.run["100","100",
 "/home/ruud/rune/.worktrees/benchmarks/examples/benchmarks/sphere-lazy/normal.pixels"]="100:1000000 A7AEE0E71A34BF89")
