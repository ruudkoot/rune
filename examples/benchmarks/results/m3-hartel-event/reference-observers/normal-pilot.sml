structure Lazy=BenchEventFn(BenchNeed)
structure Strict=BenchEventFn(BenchStrict)
structure LazyDriver=BenchEventDriverFn(Lazy)
structure StrictDriver=BenchEventDriverFn(Strict)
val base="/home/ruud/rune/.worktrees/benchmarks/tests/out/benchmarks/event-originals/"
val args=["100","100000",base^"cases/200.state"]
val result=case CommandLine.arguments()of["lazy"]=>LazyDriver.run args|["strict"]=>StrictDriver.run args|_=>raise Match
val _=print(result^"\n")
