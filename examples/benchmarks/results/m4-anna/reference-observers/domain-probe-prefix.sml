fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor DomainTests(structure D:BENCH_SUSPEND val label:string)=struct
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
 val source=TextIO.openIn"tests/out/benchmarks/nofib-anna-originals/domains.reference"
 val index=ref 0
 fun check phase actual=let
    val expected=case TextIO.inputLine source of SOME s=>String.substring(s,0,size s-1)|NONE=>raise Fail"domain oracle EOF"
    in if actual=expected then print("PASS "^label^" domain-"^Int.toString(!index)^" "^phase^"\n")
       else let val f=TextIO.openOut("tests/out/benchmarks/nofib-anna-originals/domain-failure-"^label^".actual")
         in TextIO.output(f,actual^"\nEXPECTED\n"^expected);TextIO.closeOut f;raise Fail("abstract domain "^phase)end end
