fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor FrontierTests(structure D:BENCH_SUSPEND val label:string)=struct
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

 val source=TextIO.openIn"tests/out/benchmarks/nofib-anna-originals/frontier.reference"
 val counter=ref 0
 fun check actual=let
    val expected=case TextIO.inputLine source of SOME s=>String.substring(s,0,size s-1)|NONE=>raise Fail"frontier oracle EOF"
    in counter:= !counter+1;
       if actual=expected then print("PASS "^label^" frontier-"^Int.toString(!counter)^"\n")
       else (print("ACTUAL "^actual^"\nEXPECTED "^expected^"\n");raise Fail"frontier mismatch")end
 fun finite roots=List.foldr(fn(x,xs)=>K.F.cons(x,xs))(K.F.empty())roots
 val two=K.cell K.Two
 val one=K.cell(K.Lift1(finite[two]))
 val double=K.cell(K.Lift2(finite[two]))
 val product=K.cell(K.Lift1(finite[two,two]))
 fun unary domain=let
      val function=K.cell(K.Func(finite[domain],domain))
      val body=K.cell(K.HVar(K.name"x"))
      val expression=K.cell(K.HLam(finite[K.name"x"],body))
    in(function,expression)end
 fun binary domain=let
      val function=K.cell(K.Func(finite[domain,domain],domain))
      val x=K.cell(K.HVar(K.name"x"))
      val y=K.cell(K.HVar(K.name"y"))
      val body=K.cell(K.HMeet(finite[x,y]))
      val expression=K.cell(K.HLam(finite[K.name"x",K.name"y"],body))
    in(function,expression)end
 val cases=List.map unary[two,one,double,product]@List.map binary[two,one,double]
 fun run mode naive(domain,expression)=let
      val arguments=case D.force domain of K.Func(args,_)=>args|_=>raise Fail"function"
      val upper=case D.force(K.topRoute domain)of K.Rep r=>r|_=>raise Fail"upper"
      val lower=case D.force(K.bottomRoute domain)of K.Rep r=>r|_=>raise Fail"lower"
      val bounds=K.combineBounds upper lower
      val(result,memo)=K.L.force(K.findData mode expression domain arguments arguments bounds(fn x=>x)naive(fn()=>K.F.empty())(K.F.empty()))
      val observed=pair(rep result)(seq(fn entry=>let val(args,result)=D.force entry
         in pair(seq route args)(route result)end)memo)
    in check observed end
 val _=List.app(fn mode=>List.app(fn naive=>List.app(run mode naive)cases)[false,true])[K.Safe,K.Live]
 val _=TextIO.closeIn source
end
structure Need=FrontierTests(structure D=BenchNeed val label="lazy")
structure Strict=FrontierTests(structure D=BenchStrict val label="strict")
