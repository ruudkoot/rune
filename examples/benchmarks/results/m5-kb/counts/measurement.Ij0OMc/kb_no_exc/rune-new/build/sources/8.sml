structure Benchmark =
struct
  val name = "kb_no_exc"
  structure Kernel = BenchSandmarkKBCompletionFn (BenchSandmarkKBOption)
  structure Driver = BenchSandmarkKBDriverFn (Kernel)
  val run = Driver.run
end
