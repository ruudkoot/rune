structure Lazy=BenchHartelTypecheckProgramFn(struct val eagerChildren=false end)
structure Strict=BenchHartelTypecheckProgramFn(struct val eagerChildren=true end)
structure LazyDriver=BenchHartelTypecheckDriverFn(Lazy)
structure StrictDriver=BenchHartelTypecheckDriverFn(Strict)
val args=["5000","tests/out/benchmarks/hartel-typecheck-originals/rows.reference"]
val result=case CommandLine.arguments()of["lazy"]=>LazyDriver.run args|["strict"]=>StrictDriver.run args|_=>raise Match
val _=if result="72610000/1195000"then print(result^"\n")else raise Fail "normal typecheck result"
