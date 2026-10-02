structure NumericalBenchTests =
struct
  val _ = T.check ("benchmark.numeric/exact", fn () => BenchInput.closeReal (33.797594890762724,33.797594890762724,0.0,0.000001))
  val _ = T.check ("benchmark.numeric/accepted-small-error", fn () => BenchInput.closeReal (33.797604890762724,33.797594890762724,0.0,0.000001))
  val _ = T.check ("benchmark.numeric/rejected-perturbation", fn () => not(BenchInput.closeReal (33.798594890762724,33.797594890762724,0.0,0.000001)))
  val _ = T.check ("benchmark.numeric/zero-reference", fn () => not(BenchInput.closeReal (0.0001,0.0,0.00001,0.0)))
  val _ = T.check ("benchmark.numeric/NaN", fn () => not(BenchInput.closeReal (0.0/0.0,1.0,0.00001,0.0)))
  val _ = T.check ("benchmark.numeric/infinity", fn () => not(BenchInput.closeReal (1.0/0.0,1.0,0.00001,0.0)))
  val _ = T.check ("benchmark.numeric/infinite-reference", fn () => not(BenchInput.closeReal (1.0,1.0/0.0,0.00001,0.00001)))
  val _ = T.check ("benchmark.numeric/NaN-reference", fn () => not(BenchInput.closeReal (1.0,0.0/0.0,0.00001,0.00001)))
  val _ = T.check ("benchmark.numeric/negative-bound", fn () => not(BenchInput.closeReal (1.0,1.0,~1.0,1.0)))
end
