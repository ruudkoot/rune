structure Lazy=BenchExpertFn(struct val eagerTerms=false end)
structure Strict=BenchExpertFn(struct val eagerTerms=true end)
structure LazyDriver=BenchExpertDriverFn(Lazy)
structure StrictDriver=BenchExpertDriverFn(Strict)
val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/expert-originals/"
val args=["10000",base^"source/runtime_files/animals",base^"source/expert.stdin",base^"cases/source.output"]
val result=case CommandLine.arguments()of["lazy"]=>LazyDriver.run args|["strict"]=>StrictDriver.run args|_=>raise Match
val _=if result="10000 5260000"then print(result^"\n")else raise Fail "normal expert result"
