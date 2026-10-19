structure Benchmark =
struct
  val name = "lambda-simple-strict"
  structure Kernel = BenchLambdaFn (BenchStrict)
  structure Driver = BenchLambdaDriverFn (Kernel)
  val run = Driver.run "simple"
end
