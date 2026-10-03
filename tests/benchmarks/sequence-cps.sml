structure BenchSequenceTests =
struct
  val _ = T.check("sequence/empty",fn () => Benchmark.test 0 = 0)
  val _ = T.check("sequence/skip-first-odd",fn () => Benchmark.test 1 = 0)
  val _ = T.check("sequence/yield-even-square",fn () => Benchmark.test 2 = 16)
  val _ = T.check("sequence/two-even-squares",fn () => Benchmark.test 4 = 52)
  val _ = T.check("sequence/inclusive-outer-loop",fn () => Benchmark.run ["4"] = "84")
  val _ = T.check("sequence/wide-inner-sum",fn () => Benchmark.test 2000 = 1339342000)
  val states : int list ref = ref []
  val source = Benchmark.Sequence(0,{unfold=fn state => fn done => fn skip => fn yield =>
    (states := state :: !states;
     case state of 0 => skip 1 | 1 => yield 2 5 | _ => done)})
  val result = Benchmark.fold source 5 IntInf.+
  val _ = T.check("sequence/skip-yield-done-state",fn () => result=10 andalso List.rev(!states)=[0,1,2])
end
