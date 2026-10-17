structure Lazy=BenchKnightsFn(BenchNeed)
structure Strict=BenchKnightsFn(BenchStrict)
val base="tests/out/benchmarks/knights-originals/"
fun check side number =
  let val path=base^Int.toString side^"-"^Int.toString number^".tour"
      val args=["1",Int.toString side,Int.toString number,path]
  in print(Lazy.run args^" lazy\n");print(Strict.run args^" strict\n")end
val _=List.app(fn(s,n)=>check s n)[(6,1),(8,1),(8,3),(14,1),(20,1),(4,1),(8,0)]
