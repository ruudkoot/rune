structure CompLabNormal=struct
 structure N=BenchCompLabFn(BenchNeed)
 structure E=BenchCompLabFn(BenchStrict)
 structure NC=BenchCompLabCheckFn(N)
 structure EC=BenchCompLabCheckFn(E)
 fun run label f mode=let val result=f mode["100","5","1280","cases/3-5-1280-zift.reference","2899651/52401"]
   in print(label^" "^result^"\n");TextIO.flushOut TextIO.stdOut end
 val _=run"need/zift"NC.run true
 val _=run"strict/zift"EC.run true
 val _=run"need/plain"NC.run false
 val _=run"strict/plain"EC.run false
end
