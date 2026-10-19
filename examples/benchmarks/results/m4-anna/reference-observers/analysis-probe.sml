fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor AnalysisTests(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchAnnaFn(D)
 fun list f values="["^String.concatWith","(List.map f values)^"]"
 fun seq f values=let fun items values=case D.force values of K.F.Nil=>[]
       |K.F.Cons(x,rest)=>f x::items rest
   in list(fn x=>x)(items values)end
 fun pair a b="("^a^","^b^")"
 fun route value=case D.force value of K.Zero=>"0"|K.One=>"1"|K.Stop1=>"s1"
   |K.Up1 rs=>"u1"^seq route rs|K.Stop2=>"s2"|K.Up2=>"u2"|K.UpUp2 rs=>"uu2"^seq route rs
   |K.Rep r=>"r"^rep r
 and rep value=case D.force value of K.RepTwo f=>"t"^frontier f
   |K.Rep1(f,hs)=>"l"^pair(frontier f)(seq rep hs)
   |K.Rep2(f,m,hs)=>"d("^String.concatWith","[frontier f,frontier m,seq rep hs]^")"
 and frontier value=let val K.Min1Max0(a,ones,zeros)=D.force value
   in"("^String.concatWith","[K.signed a,seq frel ones,seq frel zeros]^")"end
 and frel value=let val K.MkFrel rs=D.force value in seq route rs end
 fun boolean true="True"|boolean false="False"


 val p="tests/out/benchmarks/nofib-anna-originals/"
 fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
 fun oneSize(size,domains)="("^K.signed size^","^seq(fn d=>K.showDomain 0 d)domains^")"
 fun info value=case D.force value of
    K.SAResult(n,d,r)=>"R("^String.concatWith","[K.quoteName n,K.showDomain 0 d,route r]^")"
   |K.SASearch(mode,n,size,count)=>"S("^String.concatWith","[
       case mode of K.Safe=>"s"|K.Live=>"l",K.quoteName n,K.signed size,K.signed count]^")"
   |K.SASizes(n,used,unused)=>"Z("^String.concatWith","[K.quoteName n,seq(fn value=>oneSize(D.force value))used,
       seq(fn value=>oneSize(D.force value))unused]^")"
   |K.SAGiveUp names=>"G"^K.namesShown names
   |_=>raise Fail"unexpected analysis record"
 fun one(profile,file)=
   let val table=K.readTable(K.input(read(p^"source/runtime_files/anna_table")))
       val(_,result)=K.prepareAnalysis(read(p^"source/"^file))table
       val output=TextIO.openOut(p^"analysis-"^profile^"-"^label^".actual")
       val expected=TextIO.openIn(p^"analysis-"^profile^".reference")
       val count=ref 0
       fun loop values=case D.force values of K.F.Nil=>()
         |K.F.Cons(x,rest)=>let val actual=info x^"\n"
              val wanted=case TextIO.inputLine expected of SOME s=>s|NONE=>raise Fail"reference EOF"
           in count:= !count+1;TextIO.output(output,actual);TextIO.flushOut output;
              if actual=wanted then loop rest
              else (print("ACTUAL "^actual^"EXPECTED "^wanted);raise Fail("analysis "^profile^" line "^Int.toString(!count)))end
       val _=loop result
       val _=case TextIO.inputLine expected of NONE=>()|SOME _=>raise Fail"extra reference records"
   in TextIO.closeOut output;TextIO.closeIn expected;print("PASS "^label^" complete analysis "^profile^" "^Int.toString(!count)^"\n")end
 val _=List.app one[("smoke","anna.faststdin"),("normal","anna.stdin"),("large","anna.slowstdin")]
end
structure Need=AnalysisTests(structure D=BenchNeed val label="lazy")
structure Strict=AnalysisTests(structure D=BenchStrict val label="strict")
