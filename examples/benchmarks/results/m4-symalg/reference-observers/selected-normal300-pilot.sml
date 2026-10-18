structure SymalgNormal=struct
 structure N=BenchSymalgFn(BenchNeed)
 structure E=BenchSymalgFn(BenchStrict)
 structure NC=BenchSymalgCheckFn(N)
 structure EC=BenchSymalgCheckFn(E)
 val _=print("need "^NC.run["selected-normal300.stdin","selected-normal300.numbers.reference","selected-normal300.stdout"]^"\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print("strict "^EC.run["selected-normal300.stdin","selected-normal300.numbers.reference","selected-normal300.stdout"]^"\n")
end
