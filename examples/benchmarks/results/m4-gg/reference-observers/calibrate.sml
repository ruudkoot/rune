structure Need=BenchGGDriverFn(BenchNeed)
structure Strict=BenchGGDriverFn(BenchStrict)
structure Main=struct
 val base="tests/out/benchmarks/gg-originals/"
 val _=List.app(fn mode=>
   let val args=["500",base^"source/gg.stdin",base^mode^"-normal.ps","landscape","-"]
   in print("Need "^mode^" normal "^Need.run mode args^"\n");
      TextIO.flushOut TextIO.stdOut;
      print("Strict "^mode^" normal "^Strict.run mode args^"\n");
      TextIO.flushOut TextIO.stdOut end)["activity","spark","pool"]
end
