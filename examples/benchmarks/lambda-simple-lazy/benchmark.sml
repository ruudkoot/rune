structure Benchmark =
struct
  val name = "lambda-simple-lazy"
  structure Kernel = BenchLambdaFn (BenchNeed)
  structure Driver = BenchLambdaDriverFn (Kernel)
  val run = Driver.run "simple"
end
