structure Lazy=BenchEventFn(BenchNeed)
structure Strict=BenchEventFn(BenchStrict)
val _=List.app(fn n=>(print(Int.toString n^" "^Lazy.benchmark n);print(Int.toString n^" strict "^Strict.benchmark n)))[0,1,3,25,28,50,100,200,1000]
