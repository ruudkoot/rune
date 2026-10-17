structure Benchmark =
struct
  val name = "lambda-monad-lazy"
  structure Kernel = BenchLambdaFn (BenchNeed)
  structure Driver = BenchLambdaDriverFn (Kernel)
  val run = Driver.run "monad"
end
