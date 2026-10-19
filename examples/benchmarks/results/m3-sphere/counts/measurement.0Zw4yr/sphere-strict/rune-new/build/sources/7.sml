structure Benchmark =
struct
  val name = "sphere-strict"
  structure Kernel = BenchSphereFn (BenchStrict)
  structure Driver = BenchSphereDriverFn (Kernel)
  val run = Driver.run
end
