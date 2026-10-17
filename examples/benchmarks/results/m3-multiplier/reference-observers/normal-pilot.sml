structure Lazy=BenchMultiplierFn(struct val eagerBinary=false end)
structure Strict=BenchMultiplierFn(struct val eagerBinary=true end)
structure LazyDriver=BenchMultiplierDriverFn(Lazy)
structure StrictDriver=BenchMultiplierDriverFn(Strict)
val result=case CommandLine.arguments()of["lazy",width,path]=>LazyDriver.run[width,"2000",path]
 |["strict",width,path]=>StrictDriver.run[width,"2000",path]|_=>raise Match
val _=print(result^"\n")
