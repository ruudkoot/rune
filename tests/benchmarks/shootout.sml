structure BenchShootoutTests =
struct
  val _ = T.check("fasta/binary32-ties-even",fn () =>
    Real.==(BenchFasta.single(1.0+1.0/16777216.0),1.0) andalso
    Real.==(BenchFasta.single(1.0+3.0/16777216.0),1.0+2.0/8388608.0))
  val _ = T.check("fasta/IUB-cutoffs",fn () => List.map #2 (BenchFasta.cutoffs BenchFasta.iub) =
    [37792,54588,71384,109176,111975,114774,117574,120373,123172,125972,128771,131570,134370,137169,139968])
  val _ = T.check("fasta/human-cutoffs",fn () => List.map #2 (BenchFasta.cutoffs BenchFasta.homo) =
    [42404,70117,97767,139968])
  val fixture = List.tabulate(37,fn i => Real.fromInt i)
  fun change i delta = List.tabulate(37,fn j => Real.fromInt j+(if i=j then delta else 0.0))
  val _ = T.check("n-body/full-state",fn () => Benchmark.matches fixture fixture)
  val _ = T.check("n-body/changed-state-rejected",fn () => not(Benchmark.matches(change 20 0.01)fixture))
  val _ = T.check("n-body/changed-energy-rejected",fn () => not(Benchmark.matches(change 1 0.01)fixture))
  val _ = T.check("n-body/truncated-state-rejected",fn () => not(Benchmark.matches(List.take(fixture,36))fixture))
  val _ = T.check("n-body/nonfinite-state-rejected",fn () => not(Benchmark.matches((0.0/0.0)::List.tl fixture)fixture))
  val _ = T.check("n-body/within-bound",fn () => Benchmark.matches(change 20 1.0E~12)fixture)
  val _ = T.check("n-body/outside-bound",fn () => not(Benchmark.matches(change 20 1.0E~7)fixture))
  val _ = T.check("n-body/large-within-bound",fn () => Benchmark.matchesWith(2.0E~8,2.0E~10)(change 20 1.0E~9)fixture)
  val _ = T.check("n-body/large-outside-bound",fn () => not(Benchmark.matchesWith(2.0E~8,2.0E~10)(change 20 1.0E~6)fixture))
end
