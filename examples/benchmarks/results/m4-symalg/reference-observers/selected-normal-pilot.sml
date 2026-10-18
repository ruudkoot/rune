structure SymalgNormal=struct
 structure N=BenchSymalgFn(BenchNeed)
 structure E=BenchSymalgFn(BenchStrict)
 structure NC=BenchSymalgCheckFn(N)
 structure EC=BenchSymalgCheckFn(E)
 val _=print("need "^NC.run["selected-normal.stdin","selected-normal.numbers.reference","selected-normal.stdout"]^"\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print("strict "^EC.run["selected-normal.stdin","selected-normal.numbers.reference","selected-normal.stdout"]^"\n")
end
