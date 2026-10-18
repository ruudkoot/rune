structure CacheprofLargeTests=struct
 structure N=BenchCacheprofFn(BenchNeed)
 structure E=BenchCacheprofFn(BenchStrict)
 structure NC=BenchCacheprofCheckFn(N)
 structure EC=BenchCacheprofCheckFn(E)
 fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
 val _=T.check("cacheprof-large/materialized-N",fn()=>N.rendered 2(read"full.s")=read"full.annotated")
 val _=T.check("cacheprof-large/materialized-E",fn()=>E.rendered 2(read"full.s")=read"full.annotated")
 val _=T.check("cacheprof-large/streamed-N",fn()=>NC.runRaw["full.s","full.raw.reference","hooks.s"]="1671273")
 val _=T.check("cacheprof-large/streamed-E",fn()=>EC.runRaw["full.s","full.raw.reference","hooks.s"]="1671273")
end
