structure Benchmark =
struct
  val name = "sphere-lazy"
  structure Kernel = BenchSphereFn (BenchNeed)
  structure Driver = BenchSphereDriverFn (Kernel)
  val run = Driver.run
end
