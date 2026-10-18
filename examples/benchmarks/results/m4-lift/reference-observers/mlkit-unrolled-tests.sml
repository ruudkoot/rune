structure LiftTests=struct
 structure N=BenchLiftFn(val strict=false)
 structure E=BenchLiftFn(val strict=true)
 structure NS=BenchLiftSerializeFn(N)
 structure ES=BenchLiftSerializeFn(E)
 fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
 fun check key actual path=T.check("lift/"^key,fn()=>actual^"\n"=read path)
 fun need(index,(_,input))=(check("need/input/"^Int.toString index)(NS.expression NS.name input)("case-"^Int.toString index^"-input.json");
   check("need/plain/"^Int.toString index)(NS.supercombinators(N.lambdaLift input))("case-"^Int.toString index^"-plain.json");
   check("need/full/"^Int.toString index)(NS.supercombinators(N.fullyLazyLift input))("case-"^Int.toString index^"-full.json"))
 fun strict(index,(_,input))=(check("strict/input/"^Int.toString index)(ES.expression ES.name input)("case-"^Int.toString index^"-input.json");
   check("strict/plain/"^Int.toString index)(ES.supercombinators(E.lambdaLift input))("case-"^Int.toString index^"-plain.json");
   check("strict/full/"^Int.toString index)(ES.supercombinators(E.fullyLazyLift input))("case-"^Int.toString index^"-full.json"))
 val _=need(0,List.nth(N.cases(),0))
 val _=need(1,List.nth(N.cases(),1))
 val _=need(2,List.nth(N.cases(),2))
 val _=need(3,List.nth(N.cases(),3))
 val _=need(4,List.nth(N.cases(),4))
 val _=need(5,List.nth(N.cases(),5))
 val _=need(6,List.nth(N.cases(),6))

 val _=strict(0,List.nth(E.cases(),0))
 val _=strict(1,List.nth(E.cases(),1))
 val _=strict(2,List.nth(E.cases(),2))
 val _=strict(3,List.nth(E.cases(),3))
 val _=strict(4,List.nth(E.cases(),4))
 val _=strict(5,List.nth(E.cases(),5))
 val _=strict(6,List.nth(E.cases(),6))


 structure NP=BenchLiftPrintFn(N)
 structure EP=BenchLiftPrintFn(E)
 structure NC=BenchLiftCheckFn(N)
 structure EC=BenchLiftCheckFn(E)
 structure L=BenchLazy
 exception Demanded
 fun demanded Demanded=true|demanded _=false
 val touches=ref 0
 val deferred:N.name N.expr=L.delay(fn()=>(touches:= !touches+1;N.EConst(N.CNum 42)))
 val _=T.check("lift/need-boundary-defers",fn()=>
   (ignore(N.boundaryExpr N.forceName deferred); !touches=0))
 val _=T.check("lift/shared-node-forced-once",fn()=>
   (ignore(L.force deferred);ignore(L.force deferred); !touches=1))
 val strictTouches=ref 0
 val strictNode:E.name E.expr=L.delay(fn()=>(strictTouches:= !strictTouches+1;E.EConst(E.CNum 42)))
 val _=T.check("lift/strict-boundary-demands",fn()=>
   (ignore(E.boundaryExpr E.forceName strictNode); !strictTouches=1))
 val _=T.raises("lift/strict-boundary-poison",demanded,fn()=>
   E.boundaryExpr E.forceName(L.delay(fn()=>raise Demanded)))
 val _=T.check("lift/need-variable-tag-shared",fn()=>
   let val hits=ref 0 val nm=L.delay(fn()=>(hits:= !hits+1;"x"))
       val fv=N.freeVars(N.var nm)
       val first=N.tag fv val second=N.tag fv
   in !hits=0 andalso List.map L.force first=["x"]andalso
      List.map L.force second=["x"]andalso !hits=1 end)
 val _=T.check("lift/free-vars-sorted-deduplicated",fn()=>
   List.map L.force(N.tag(N.freeVars(N.app(N.app(N.variable"z")(N.variable"a"))(N.variable"z"))))=["a","z"])
 val _=T.check("lift/recursive-let-binds-rhs",fn()=>
   List.null(N.tag(N.freeVars(N.lett true[(N.named"x",N.variable"x")](N.variable"x")))))
 val _=T.check("lift/nonrecursive-let-retains-rhs-free",fn()=>
   List.map L.force(N.tag(N.freeVars(N.lett false[(N.named"x",N.variable"x")](N.variable"x"))))=["x"])
 val _=T.check("lift/rec-renaming-knot",fn()=>
   let val info=L.delay(fn()=>0)
       val ast=L.delay(fn()=>N.ELet(true,[((N.named"x",info),N.variable"x")],N.variable"x"))
       val output=N.rename ast
   in case L.force output of N.ELet(true,[((name,_),rhs)],body)=>
        L.force name="x0"andalso
        (case L.force rhs of N.EVar n=>L.force n="x0"|_=>false)andalso
        (case L.force body of N.EVar n=>L.force n="x0"|_=>false)
      |_=>false end)
 val _=T.check("lift/source-lambda-supply-quirk",fn()=>
   let val z=L.delay(fn()=>0)
       val ast=L.delay(fn()=>N.EAp(N.lam[(N.named"x",z)](N.lam[(N.named"y",z)](N.variable"x")),
         N.lam[(N.named"z",z)](N.variable"z")))
   in case L.force(N.rename ast)of N.EAp(a,b)=>
       (case(L.force a,L.force b)of(N.ELam([(x,_)],inside),N.ELam([(z,_)],_))=>
         L.force x="x0"andalso L.force z="z1"andalso
         (case L.force inside of N.ELam([(y,_)],_)=>L.force y="y1"|_=>false)
       |_=>false)|_=>false end)
 val _=T.check("lift/arbitrary-precision-constant",fn()=>
   let val n=valOf(IntInf.fromString"123456789012345678901234567890")
   in NP.expression(N.cn n)="123456789012345678901234567890"andalso
      EP.expression(E.cn n)="123456789012345678901234567890"end)
 val _=T.check("lift/pretty-negative",fn()=>NP.expression(N.cn ~42)="-42")
 val _=T.check("lift/printer-pending-indent",fn()=>
   NP.mkstr(NP.concat[NP.text"a\n",NP.indent 4(NP.text"b\nc"),NP.text"\nd"])="a\n    b\n    c\nd")
 val _=T.check("lift/printer-delayed-expression",fn()=>
   let val hits=ref 0 val expr=L.delay(fn()=>(hits:= !hits+1;N.EConst(N.CNum 1)))
       val sequence=NP.ppr NP.name expr
   in !hits=0 andalso NP.mkstr sequence="1"andalso !hits=1 end)
 val _=T.check("lift/complete-report-need",fn()=>NC.report(N.program())=read"report.reference")
 val _=T.check("lift/complete-report-strict",fn()=>EC.report(E.program())=read"report.reference")
 val wantedHash=String.substring(read"hash.reference",0,16)
 val _=T.check("lift/Word64-source-hash",fn()=>Word64.fmt StringCvt.HEX(NC.hash(read"report.reference"))="8A2CD0A394A3204D")
 val _=T.check("lift/zero-repetitions",fn()=>NC.run["0","report.reference",wantedHash]="0:0")
 val _=T.check("lift/smoke-both-transforms-need",fn()=>NC.run["1","report.reference",wantedHash]="1:1948")
 val _=T.check("lift/smoke-both-transforms-strict",fn()=>EC.run["1","report.reference",wantedHash]="1:1948")
 val _=T.raises("lift/reject-incorrect-report",fn Fail _=>true|_=>false,fn()=>NC.run["1","wrong.report",wantedHash])
 val _=T.raises("lift/reject-incorrect-hash",fn Fail _=>true|_=>false,fn()=>EC.run["1","report.reference","0"])
end
