fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
val failures=ref 0
functor GrammarProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHappyFn(D)
 fun one name=
   let val root="tests/out/benchmarks/nofib-happy-originals/grammar-data/"
       val actual=K.grammarJSON(read(root^name^".input"))^"\n"
   in if actual=read(root^name^".reference")then print("PASS "^label^" "^name^"\n")
      else let val f=TextIO.openOut(root^name^"-"^label^".actual")
           in TextIO.output(f,actual);TextIO.closeOut f;
              failures:= !failures+1;print("FAIL "^label^" "^name^"\n")end end
 val _=List.app one ["default","basic","precedence","typed","multiple-starts","unknown-token","duplicate-name","bad-reference","empty-rightmost","unknown-precedence","quote-normalization","attributes","attribute-groups","attribute-rightmost","attribute-terminal-name","attribute-range","attribute-zero","attribute-empty","monad-lexer"]
end
structure NeedGrammar=GrammarProbeFn(structure D=BenchNeed val label="need")
structure StrictGrammar=GrammarProbeFn(structure D=BenchStrict val label="strict")
val _=OS.Process.exit(if !failures=0 then OS.Process.success else OS.Process.failure)
