structure SolidNormal=struct
 structure N=BenchSolidFn(BenchNeed)
 structure E=BenchSolidFn(BenchStrict)
 structure NC=BenchSolidCheckFn(N)
 structure EC=BenchSolidCheckFn(E)
 val args=["200","9","scene.input","areas.reference"]
 val _=print("need "^NC.run args^"\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print("strict "^EC.run args^"\n")
end
