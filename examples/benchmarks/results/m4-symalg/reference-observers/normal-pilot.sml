structure SymalgNormal=struct
 structure N=BenchSymalgFn(BenchNeed)
 structure E=BenchSymalgFn(BenchStrict)
 structure NC=BenchSymalgCheckFn(N)
 structure EC=BenchSymalgCheckFn(E)
 val _=print("need "^NC.run["source/symalg.faststdin","source-fast.numbers.reference","source-fast.stdout"]^"\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print("strict "^EC.run["source/symalg.faststdin","source-fast.numbers.reference","source-fast.stdout"]^"\n")
end
