structure Benchmark =
struct
  val name = "lambda-monad-strict"
  structure Kernel = BenchLambdaFn (BenchStrict)
  structure Driver = BenchLambdaDriverFn (Kernel)
  val run = Driver.run "monad"
end
