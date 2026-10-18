structure Need=BenchIdaFn(BenchNeed)
structure Strict=BenchIdaFn(BenchStrict)
structure NeedDriver=BenchIdaDriverFn(Need)
structure StrictDriver=BenchIdaDriverFn(Strict)
val args=["600","3","tests/out/benchmarks/ida-originals/normal.one"]
fun run name f=let val start=Time.now() val result=f args
  in print(name^" "^result^" "^Time.toString(Time.-(Time.now(),start))^"\n")end
val _=run "lazy" NeedDriver.run
val _=run "strict" StrictDriver.run
