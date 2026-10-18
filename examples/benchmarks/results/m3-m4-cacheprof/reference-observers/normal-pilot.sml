structure CacheprofNormal=struct
 structure N=BenchCacheprofFn(BenchNeed)
 structure E=BenchCacheprofFn(BenchStrict)
 structure NC=BenchCacheprofCheckFn(N)
 structure EC=BenchCacheprofCheckFn(E)
 val _=print("need/raw "^NC.runRaw["real/source/cacheprof.stdin","gc/normal.stdout","gc/source/cacheprof_hooks2_x86.s"]^"\n")
 val _=print("strict/raw "^EC.runRaw["real/source/cacheprof.stdin","gc/normal.stdout","gc/source/cacheprof_hooks2_x86.s"]^"\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print("need/forced "^NC.runForced["200","real/source/cacheprof.stdin","normal.annotated","gc/source/cacheprof_hooks2_x86.s"]^"\n")
 val _=TextIO.flushOut TextIO.stdOut
 val _=print("strict/forced "^EC.runForced["200","real/source/cacheprof.stdin","normal.annotated","gc/source/cacheprof_hooks2_x86.s"]^"\n")
end
