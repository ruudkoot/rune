structure TreeJoin = BenchTreeJoinFn(BenchNeed)
structure Benchmark =
struct
  val name = "treejoin-lazy"
  val run = TreeJoin.run
end
