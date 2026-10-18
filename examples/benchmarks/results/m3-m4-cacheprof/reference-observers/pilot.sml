structure CacheprofPilot=struct
 structure N=BenchCacheprofFn(BenchNeed)
 structure E=BenchCacheprofFn(BenchStrict)
 fun read file=let val stream=TextIO.openIn file in TextIO.inputAll stream before TextIO.closeIn stream end
 fun write file text=let val stream=TextIO.openOut file in TextIO.output(stream,text);TextIO.closeOut stream end
 fun test label source reference=
   let val text=read source val wanted=read reference
       val need=N.rendered 2 text val strict=E.rendered 2 text
       val _=write("need-"^label^".annotated")need
       val _=write("strict-"^label^".annotated")strict
       val _=if need=wanted then print("PASS need "^label^"\n")else raise Fail("need "^label^" annotated assembly")
       val _=if strict=wanted then print("PASS strict "^label^"\n")else raise Fail("strict "^label^" annotated assembly")
       val _=TextIO.flushOut TextIO.stdOut
   in()end
 val _=test"fast""real/source/cacheprof.faststdin""source-fast.annotated"
 val _=test"normal""real/source/cacheprof.stdin""normal.annotated"
 val _=test"slow""real/source/cacheprof.slowstdin""source-slow.annotated"
end
