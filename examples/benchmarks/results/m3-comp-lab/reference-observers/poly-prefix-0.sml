structure CompLabTests=struct
 structure N=BenchCompLabFn(BenchNeed)
 structure E=BenchCompLabFn(BenchStrict)
 structure NC=BenchCompLabCheckFn(N)
 structure EC=BenchCompLabCheckFn(E)
 structure L=BenchLazy
 fun check name f=T.check("comp-lab/"^name,f)
 fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end

end
