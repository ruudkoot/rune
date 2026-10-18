fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
val failures=ref 0
functor AttributeProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 fun one name=List.app(fn mode=>
   let val root="tests/out/benchmarks/nofib-happy-originals/attribute-data/"
       val actual=K.AG.json mode(read(root^name^".input"))^"\n"
   in if actual=read(root^name^"-"^mode^".reference")then print("PASS "^label^" "^name^" "^mode^"\n")
      else let val f=TextIO.openOut(root^name^"-"^mode^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;failures:= !failures+1;print("FAIL "^label^" "^name^" "^mode^"\n")end end)["tokens","rules"]
 val _=List.app one ["empty","whitespace","simple","attrs","right","nested","embedded-dollar","where-prefix","bad-attr","dangling-dot","trailing-dot","underscore-attr","char-quotes","empty-values","terminal-attrs","right-inside-braces","two-values","zero","unknown-dollar"]
end
structure NeedAttributes=AttributeProbeFn(structure D=BenchNeed val label="need")
structure StrictAttributes=AttributeProbeFn(structure D=BenchStrict val label="strict")
val _=OS.Process.exit(if !failures=0 then OS.Process.success else OS.Process.failure)
