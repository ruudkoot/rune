structure Benchmark =
struct
  val name = "integrate-lazy"
  val ints = BenchStream.iterate (fn x => x+1.0) (BenchLazy.delay (fn () => 1.0))
  val zarks = BenchStream.zipWith (fn (u,v) => BenchIntegrate.zark u v)
    ints (BenchStream.map (fn x => 2.0*x) ints)
  fun running (xs:real BenchStream.stream) = BenchStream.fix (fn self => BenchStream.Cons
    (BenchLazy.delay (fn () => BenchStream.head xs),
     BenchLazy.delay (fn () => BenchLazy.force
       (BenchStream.zipWith (fn (x,y) => x+y) (BenchStream.tail xs) self))))
  val rtotals = running zarks
  val itotals = running (BenchStream.map BenchIntegrate.fourth ints)
  val errors = BenchStream.map (fn x => x*x)
    (BenchStream.zipWith (fn (x,y) => x-y) rtotals itotals)
  fun run [size,reference] =
    let val n=BenchInput.between (1,5000000) (BenchInput.integer size)
        val _=if List.exists (fn p=>p=reference)
          ["expected/smoke.txt","expected/normal.txt","expected/large.txt"] then () else raise Fail "integration reference path"
        val result=BenchStream.foldPrefix (fn (x,a)=>a+x) 0.0 n errors
    in BenchIntegrate.checked n (result, BenchStream.nth rtotals (n-1),
      BenchStream.nth itotals (n-1)) reference end
    | run _ = raise Fail "integrate expects range reference"
end
