structure NeedWave=BenchWave4Fn(BenchNeed)
structure StrictWave=BenchWave4Fn(BenchStrict)
val _=List.app(fn n=>
 (print(Int.toString n^" lazy "^NeedWave.sumcode(NeedWave.output(NeedWave.solve n)));
  print(Int.toString n^" strict "^StrictWave.sumcode(StrictWave.output(StrictWave.solve n)));
  TextIO.flushOut TextIO.stdOut))[0,1,2,8,80]
