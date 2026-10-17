structure Pilot =
struct
  val _=List.app(fn(name,steps,count)=>
    print(name^" "^BenchManyBodyCheck.run[Int.toString steps,Int.toString count,
      "tests/out/benchmarks/manybody-originals/"^name^".state"]^"\n"))
    [("one",0,1),("small-zero",0,4),("small-one",1,4),("small-two",2,4),("smoke",1,16),("normal",20,256)]
end
