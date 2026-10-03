structure TreeJoin = BenchTreeJoinFn(BenchStrict)
structure Benchmark =
struct
  val name = "treejoin-strict"
  val run = TreeJoin.run
end
