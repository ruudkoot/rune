from pathlib import Path
p=Path(__file__).resolve().parent
body=r'''
 structure K=BenchLambdaFn(D)
 structure Driver=BenchLambdaDriverFn(K)
 fun label text="lambda/"^policy^"/"^text
 val env=K.delay(fn()=>K.Binding("outer",K.con 91,K.empty))
 val xenv=K.delay(fn()=>K.Binding("x",K.con 10,K.empty))
 val cases=
  List.map(fn t=>(K.empty,t))[
   K.zero(K.con 0,K.con 1,K.con 2),K.zero(K.con 1,K.con 2,K.con 1),
   K.node K.Incr,K.con ~7,
   K.app(K.lam("x",K.add(K.variable"x",K.con 1)),K.con 12),
   K.app(K.lam("x",K.add(K.variable"x",K.variable"x")),K.con 9),
   K.app(K.lam("x",K.con 3),K.variable"undefined"),
   K.zero(K.lam("x",K.variable"x"),K.con 9,K.con 8),
   K.app(K.lam("x",K.app(K.lam("x",K.variable"x"),K.con 7)),K.con 2),
   K.app(K.lam("x",K.app(K.lam("f",K.app(K.variable"f",K.con 0)),
      K.lam("z",K.variable"x"))),K.con 23)]
  @List.tabulate(21,fn n=>(K.empty,K.app(K.sum0,K.con n)))
  @[(env,K.add(K.con 4,K.node(K.Thunk(K.variable"outer",
       K.delay(fn()=>K.Binding("outer",K.con 13,K.empty)))))),
    (xenv,K.lam("y",K.add(K.variable"x",K.variable"y")))]
 val base="PRIVATE/"
 val f=TextIO.openIn(base^"terms.reference")
 val reference=String.tokens(fn c=>c= #"\n")(TextIO.inputAll f)
 val _=TextIO.closeIn f
 val _=List.app(fn((initial,term),row)=>
   case String.fields(fn c=>c= #"\t")row of[id,direct,monadic,env]=>
    let val _=T.check(label(id^"/direct"),fn()=>K.pretty 0(K.simple initial term)=direct)
        val _=T.check(label(id^"/state"),fn()=>
          let val(value,_)=K.traverse term initial in K.pretty 0 value=monadic end)
        val _=T.check(label(id^"/caller-environment"),fn()=>
          let val(_,after)=K.traverse term initial in K.prettyEnv after=env end)
    in()end
   |_=>raise Fail "invalid lambda observer row")(ListPair.zip(cases,reference))
 val _=List.app(fn n=>List.app(fn style=>
   T.check(label(style^"/independent-sum-"^Int.toString n),fn()=>
      let val answer=n*(n+1)div 2
          val wanted=if style="simple"then"Con "^Int.toString answer^"\n"
            else Int.toString answer^"  []\n"
      in K.evaluate style n=wanted end))["simple","monad"])[0,1,2,3,7,15,31]
 val _=List.app(fn(style,n,wanted)=>T.check(label(style^"/driver-profile"),fn()=>
   Driver.run style["1",Int.toString n]=wanted))
   [("simple",80,"1:9"),("monad",80,"1:9")]
 val _=T.check(label"zero-repetitions",fn()=>Driver.run"simple"["0","20"]="0:0")
 val _=T.check(label"undefined-variable-is-rejected",fn()=>
   ((K.integer(K.simple K.empty(K.variable"absent"));false)handle Fail _=>true))
 val _=T.check(label"bad-application-is-rejected",fn()=>
   ((K.integer(K.simple K.empty(K.app(K.con 1,K.con 2)));false)handle Fail _=>true))
 val _=T.check(label"pretty-bracketing",fn()=>
   K.pretty 2(K.add(K.con 1,K.con 2))="(1 + 2)")
'''
header='functor LambdaTestsFn(P:sig structure D:BENCH_SUSPEND val policy:string end)=struct\n structure D=P.D\n val policy=P.policy\n'
text=header+body.replace('PRIVATE',str(p))+'\nend\n'
text+='structure NeedTests=LambdaTestsFn(struct structure D=BenchNeed val policy="lazy"end)\n'
text+='structure StrictTests=LambdaTestsFn(struct structure D=BenchStrict val policy="strict"end)\n'
text+=r'''
structure LambdaDemandTests=struct
 structure K=BenchLambdaFn(BenchNeed)
 val _=T.check("lambda/demand/unused-AST-child",fn()=>
   let val bad=K.delay(fn()=>raise Fail "unused syntax field")
       val program=K.app(K.lam("x",K.con 5),bad)
   in K.integer(K.simple K.empty program)=5 andalso
      K.integer(#1(K.traverse program K.empty))=5 end)
 val _=T.check("lambda/demand/shared-argument-AST",fn()=>
   let val calls=ref 0
       val argument=K.delay(fn()=>(calls:= !calls+1;K.Con(K.delay(fn()=>9))))
       val program=K.app(K.lam("x",K.add(K.variable"x",K.variable"x")),argument)
   in K.integer(K.simple K.empty program)=18 andalso !calls=1 end)
 structure Wrong=BenchLambdaDriverFn(struct fun evaluate _ _="wrong\n"end)
 val _=T.check("lambda/checker/modified-output",fn()=>
   ((Wrong.run"simple"["1","80"];false)handle Fail _=>true))
end
'''
(p/'tests.sml').write_text(text)
print('tests generated')
