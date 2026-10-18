structure LiftTests=struct
 structure N=BenchLiftFn(val strict=false)
 structure E=BenchLiftFn(val strict=true)
 structure NCases=struct
 open N
 fun cases()=[("identity",app (lam [named "x"] (variable "x")) (cn (42:IntInf.int))),("capture",lett false [(named "a",cn (2:IntInf.int))] (app (lam [named "x"] (app (app (cf "+") (variable "a")) (variable "x"))) (cn (40:IntInf.int)))),("multi-lambda",app (app (lam [named "x",named "y"] (app (app (cf "+") (variable "x")) (variable "y"))) (cn (17:IntInf.int))) (cn (25:IntInf.int))),("shadow",app (app (lam [named "x"] (lam [named "x"] (variable "x"))) (cn (1:IntInf.int))) (cn (42:IntInf.int))),("unused-cycle",lett true [(named "bad",variable "bad")] (cn (42:IntInf.int))),("factorial",lett true [(named "fac",lam [named "n"] (app (app (app (cf "if") (app (app (cf "==") (variable "n")) (cn (0:IntInf.int)))) (cn (1:IntInf.int))) (app (app (cf "*") (variable "n")) (app (variable "fac") (app (app (cf "-") (variable "n")) (cn (1:IntInf.int)))))))] (app (variable "fac") (cn (6:IntInf.int)))),("fixed-program",lett true [(named "p",lam [named "a",named "b"] (lett false [(named "p",app (app (cf "-") (app (app (cf "+") (variable "a")) (variable "b"))) (cn (20:IntInf.int)))] (lett false [(named "m",lam [named "p",named "q"] (lett false [(named "g",app (app (cf "+") (variable "a")) (cn (6:IntInf.int)))] (lett false [(named "d",lam [named "pp"] (app (app (cf "+") (app (app (cf "+") (variable "pp")) (variable "q"))) (variable "p")))] (lett false [(named "c",lam [named "q"] (app (app (cf "+") (app (app (cf "-") (variable "q")) (variable "g"))) (variable "a")))] (app (app (cf "-") (app (app (cf "-") (app (variable "d") (app (app (cf "+") (cn (1:IntInf.int))) (variable "a")))) (app (variable "c") (app (app (cf "-") (variable "a")) (variable "b"))))) (variable "p"))))))] (lett true [(named "f",lam [named "a",named "b"] (app (app (variable "g") (variable "a")) (app (app (cf "+") (variable "b")) (cn (1:IntInf.int))))),(named "g",lam [named "x",named "y"] (app (app (variable "f") (variable "x")) (app (app (cf "+") (variable "y")) (variable "b"))))] (lett false [(named "h",lam [named "a",named "n"] (app (app (variable "m") (app (app (cf "+") (variable "n")) (cn (1:IntInf.int)))) (app (app (variable "f") (variable "a")) (variable "n"))))] (app (app (variable "h") (variable "a")) (variable "p")))))))] (app (app (variable "p") (cn (5:IntInf.int))) (cn (6:IntInf.int))))]
end
 structure NS=BenchLiftSerializeFn(N)
 structure ECases=struct
 open E
 fun cases()=[("identity",app (lam [named "x"] (variable "x")) (cn (42:IntInf.int))),("capture",lett false [(named "a",cn (2:IntInf.int))] (app (lam [named "x"] (app (app (cf "+") (variable "a")) (variable "x"))) (cn (40:IntInf.int)))),("multi-lambda",app (app (lam [named "x",named "y"] (app (app (cf "+") (variable "x")) (variable "y"))) (cn (17:IntInf.int))) (cn (25:IntInf.int))),("shadow",app (app (lam [named "x"] (lam [named "x"] (variable "x"))) (cn (1:IntInf.int))) (cn (42:IntInf.int))),("unused-cycle",lett true [(named "bad",variable "bad")] (cn (42:IntInf.int))),("factorial",lett true [(named "fac",lam [named "n"] (app (app (app (cf "if") (app (app (cf "==") (variable "n")) (cn (0:IntInf.int)))) (cn (1:IntInf.int))) (app (app (cf "*") (variable "n")) (app (variable "fac") (app (app (cf "-") (variable "n")) (cn (1:IntInf.int)))))))] (app (variable "fac") (cn (6:IntInf.int)))),("fixed-program",lett true [(named "p",lam [named "a",named "b"] (lett false [(named "p",app (app (cf "-") (app (app (cf "+") (variable "a")) (variable "b"))) (cn (20:IntInf.int)))] (lett false [(named "m",lam [named "p",named "q"] (lett false [(named "g",app (app (cf "+") (variable "a")) (cn (6:IntInf.int)))] (lett false [(named "d",lam [named "pp"] (app (app (cf "+") (app (app (cf "+") (variable "pp")) (variable "q"))) (variable "p")))] (lett false [(named "c",lam [named "q"] (app (app (cf "+") (app (app (cf "-") (variable "q")) (variable "g"))) (variable "a")))] (app (app (cf "-") (app (app (cf "-") (app (variable "d") (app (app (cf "+") (cn (1:IntInf.int))) (variable "a")))) (app (variable "c") (app (app (cf "-") (variable "a")) (variable "b"))))) (variable "p"))))))] (lett true [(named "f",lam [named "a",named "b"] (app (app (variable "g") (variable "a")) (app (app (cf "+") (variable "b")) (cn (1:IntInf.int))))),(named "g",lam [named "x",named "y"] (app (app (variable "f") (variable "x")) (app (app (cf "+") (variable "y")) (variable "b"))))] (lett false [(named "h",lam [named "a",named "n"] (app (app (variable "m") (app (app (cf "+") (variable "n")) (cn (1:IntInf.int)))) (app (app (variable "f") (variable "a")) (variable "n"))))] (app (app (variable "h") (variable "a")) (variable "p")))))))] (app (app (variable "p") (cn (5:IntInf.int))) (cn (6:IntInf.int))))]
end
 structure ES=BenchLiftSerializeFn(E)
 fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
 fun check key actual path=T.check("lift/"^key,fn()=>actual^"\n"=read path)
 fun need(index,(_,input))=(check("need/input/"^Int.toString index)(NS.expression NS.name input)("case-"^Int.toString index^"-input.json");
   check("need/plain/"^Int.toString index)(NS.supercombinators(N.lambdaLift input))("case-"^Int.toString index^"-plain.json");
   check("need/full/"^Int.toString index)(NS.supercombinators(N.fullyLazyLift input))("case-"^Int.toString index^"-full.json"))
 fun strict(index,(_,input))=(check("strict/input/"^Int.toString index)(ES.expression ES.name input)("case-"^Int.toString index^"-input.json");
   check("strict/plain/"^Int.toString index)(ES.supercombinators(E.lambdaLift input))("case-"^Int.toString index^"-plain.json");
   check("strict/full/"^Int.toString index)(ES.supercombinators(E.fullyLazyLift input))("case-"^Int.toString index^"-full.json"))
 val _=need(0,List.nth(NCases.cases(),0))
 val _=need(1,List.nth(NCases.cases(),1))
 val _=need(2,List.nth(NCases.cases(),2))
 val _=need(3,List.nth(NCases.cases(),3))
 val _=need(4,List.nth(NCases.cases(),4))
 val _=need(5,List.nth(NCases.cases(),5))
 val _=need(6,List.nth(NCases.cases(),6))

 val _=strict(0,List.nth(ECases.cases(),0))
 val _=strict(1,List.nth(ECases.cases(),1))
 val _=strict(2,List.nth(ECases.cases(),2))
 val _=strict(3,List.nth(ECases.cases(),3))
 val _=strict(4,List.nth(ECases.cases(),4))
 val _=strict(5,List.nth(ECases.cases(),5))
 val _=strict(6,List.nth(ECases.cases(),6))


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
