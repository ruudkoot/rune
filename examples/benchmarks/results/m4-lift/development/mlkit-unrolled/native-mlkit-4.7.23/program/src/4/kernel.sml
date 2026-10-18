(* Modular lambda lifting from the executable nofib paper. Names and AST fields
 * remain memoized; strict mode materializes finite pass results at boundaries. *)
functor BenchLiftFn(val strict:bool)=
struct
 structure L=BenchLazy
 type name=string L.delay
 datatype constant=CNum of IntInf.int|CBool of bool|CFun of name
 datatype 'b exprNode=EConst of constant|EVar of name
   |EAp of 'b exprNode L.delay*'b exprNode L.delay
   |ELam of 'b list*'b exprNode L.delay
   |ELet of bool*('b*'b exprNode L.delay)list*'b exprNode L.delay
 type 'b expr='b exprNode L.delay
 datatype ('b,'a)annNode=Ann of 'a L.delay*('b,'a)annBody L.delay
 and ('b,'a)annBody=AConst of constant|AVar of name
   |AAp of ('b,'a)annNode L.delay*('b,'a)annNode L.delay
   |ALam of 'b list*('b,'a)annNode L.delay
   |ALet of bool*('b*('b,'a)annNode L.delay)list*('b,'a)annNode L.delay
 type ('b,'a)ann=('b,'a)annNode L.delay
 type sc=name*name list*name expr
 fun named text=L.delay(fn()=>text)
 fun cn n=L.delay(fn()=>EConst(CNum n))
 fun cb b=L.delay(fn()=>EConst(CBool b))
 fun cf text=L.delay(fn()=>EConst(CFun(named text)))
 fun variable text=L.delay(fn()=>EVar(named text))
 fun var name=L.delay(fn()=>EVar name)
 fun app a b=L.delay(fn()=>EAp(a,b))
 fun lam args body=L.delay(fn()=>ELam(args,body))
 fun lett recursive definitions body=L.delay(fn()=>ELet(recursive,definitions,body))
fun program()= lett true [(named "p",lam [named "a",named "b"] (lett false [(named "p",app (app (cf "-") (app (app (cf "+") (variable "a")) (variable "b"))) (cn (20)))] (lett false [(named "m",lam [named "p",named "q"] (lett false [(named "g",app (app (cf "+") (variable "a")) (cn (6)))] (lett false [(named "d",lam [named "pp"] (app (app (cf "+") (app (app (cf "+") (variable "pp")) (variable "q"))) (variable "p")))] (lett false [(named "c",lam [named "q"] (app (app (cf "+") (app (app (cf "-") (variable "q")) (variable "g"))) (variable "a")))] (app (app (cf "-") (app (app (cf "-") (app (variable "d") (app (app (cf "+") (cn (1))) (variable "a")))) (app (variable "c") (app (app (cf "-") (variable "a")) (variable "b"))))) (variable "p"))))))] (lett true [(named "f",lam [named "a",named "b"] (app (app (variable "g") (variable "a")) (app (app (cf "+") (variable "b")) (cn (1))))),(named "g",lam [named "x",named "y"] (app (app (variable "f") (variable "x")) (app (app (cf "+") (variable "y")) (variable "b"))))] (lett false [(named "h",lam [named "a",named "n"] (app (app (variable "m") (app (app (cf "+") (variable "n")) (cn (1)))) (app (app (variable "f") (variable "a")) (variable "n"))))] (app (app (variable "h") (variable "a")) (variable "p")))))))] (app (app (variable "p") (cn (5))) (cn (6)))

 fun nameCompare a b=String.compare(L.force a,L.force b)
 fun union [] ys=ys|union xs []=xs
   |union(xs as x::rest)(ys as y::tail)=case nameCompare x y of
      LESS=>x::union rest ys|EQUAL=>x::union rest tail|GREATER=>y::union xs tail
 fun difference [] _=[]|difference xs []=xs
   |difference(xs as x::rest)(ys as y::tail)=case nameCompare x y of
      LESS=>x::difference rest ys|EQUAL=>difference rest tail|GREATER=>difference xs tail
 fun sortNoDups []=[]|sortNoDups(x::xs)=
   sortNoDups(List.filter(fn y=>nameCompare y x=LESS)xs)@[x]@
   sortNoDups(List.filter(fn y=>nameCompare y x=GREATER)xs)
 fun unions sets=List.foldr(fn(a,b)=>union a b)[]sets
 fun binders(definitions:('a*'b)list)=List.map #1 definitions
 fun rhss(definitions:('a*'b)list)=List.map #2 definitions
 fun tag tree=case L.force tree of Ann(annotation,_)=>L.force annotation
 fun payload tree=case L.force tree of Ann(_,body)=>L.force body
 fun annotated annotation body=L.delay(fn()=>Ann(annotation,body))
 fun freeVars expr=L.delay(fn()=>case L.force expr of
     EConst k=>Ann(L.delay(fn()=>[]),L.delay(fn()=>AConst k))
    |EVar name=>Ann(L.delay(fn()=>[name]),L.delay(fn()=>AVar name))
    |EAp(a,b)=>
       let val first=freeVars a val last=freeVars b
       in Ann(L.delay(fn()=>union(tag first)(tag last)),L.delay(fn()=>AAp(first,last)))end
    |ELam(args,body)=>
       let val result=freeVars body
       in Ann(L.delay(fn()=>difference(tag result)(sortNoDups args)),L.delay(fn()=>ALam(args,result)))end
    |ELet(recursive,definitions,body)=>
       let val names=binders definitions val set=L.delay(fn()=>sortNoDups names)
           val right=List.map freeVars(rhss definitions)
           val result=freeVars body
           val free=L.delay(fn()=>unions(List.map tag right))
           val rhsFree=L.delay(fn()=>if recursive then difference(L.force free)(L.force set)else L.force free)
           val bodyFree=L.delay(fn()=>difference(tag result)(L.force set))
       in Ann(L.delay(fn()=>union(L.force rhsFree)(L.force bodyFree)),
           L.delay(fn()=>ALet(recursive,ListPair.zip(names,right),result)))end)
 fun abstract tree=L.delay(fn()=>case payload tree of
     AConst k=>EConst k|AVar name=>EVar name
    |AAp(a,b)=>EAp(abstract a,abstract b)
    |ALam(args,body)=>
       let val names=tag tree
           val sc=lam(names@args)(abstract body)
       in L.force(List.foldl(fn(name,f)=>app f(var name))sc names)end
    |ALet(recursive,definitions,body)=>
       ELet(recursive,List.map(fn(name,rhs)=>(name,abstract rhs))definitions,abstract body))
 fun mapAccum f initial values=
   let fun loop state []=(state,[])
         |loop state(x::xs)=let val(next,value)=f state x
                                  val(last,tail)=loop next xs
                              in(last,value::tail)end
   in loop initial values end
 fun newName supply prefix=(L.delay(fn()=>L.force supply+1),
      L.delay(fn()=>L.force prefix^Int.toString(L.force supply)))
 fun collect expr=
   let fun walk supply expr=case L.force expr of
        EConst k=>(supply,[],L.delay(fn()=>EConst k))
       |EVar name=>(supply,[],var name)
       |EAp(a,b)=>
          let val(s1,bag1,a')=walk supply a val(s2,bag2,b')=walk s1 b
          in(s2,bag1@bag2,app a' b')end
       |ELam(args,body)=>
          let val(s1,bodySCs,body')=walk supply body
              val(s2,name)=newName s1(named"SC")
          in(s2,(name,args,body')::bodySCs,L.delay(fn()=>EConst(CFun name)))end
       |ELet(recursive,definitions,body)=>
          let val(s1,bodySCs,body')=walk supply body
              fun definition(state,bag)(name,rhs)=
                let val(s,found,rhs')=walk state rhs in((s,bag@found),(name,rhs'))end
              val((s2,all),definitions')=mapAccum definition(s1,bodySCs)definitions
          in(s2,all,lett recursive definitions' body')end
       val(_,scs,body)=walk(L.delay(fn()=>0))expr
   in(named"$main",[],body)::scs end
 fun separate expr=L.delay(fn()=>case L.force expr of EConst k=>EConst k|EVar v=>EVar v
    |EAp(a,b)=>EAp(separate a,separate b)
    |ELam(args,body)=>L.force(List.foldr(fn(arg,e)=>lam[arg]e)(separate body)args)
    |ELet(recursive,definitions,body)=>ELet(recursive,List.map(fn(name,rhs)=>(name,separate rhs))definitions,separate body))
 fun lookup environment name=
   let fun find []=raise Fail("unbound source variable: "^L.force name)
         |find((key,value)::rest)=if nameCompare key name=EQUAL then value else find rest
   in find environment end
 fun freeLevel names environment=List.foldl(fn(name,level)=>Int.max(L.force(lookup environment name),level))0 names
 fun addLevels expr=
   let fun walk level environment tree=L.delay(fn()=>case payload tree of
        AConst k=>Ann(L.delay(fn()=>0),L.delay(fn()=>AConst k))
       |AVar name=>Ann(L.delay(fn()=>L.force(lookup environment name)),L.delay(fn()=>AVar name))
       |AAp(a,b)=>
          let val first=walk level environment a val last=walk level environment b
          in Ann(L.delay(fn()=>Int.max(tag first,tag last)),L.delay(fn()=>AAp(first,last)))end
       |ALam(args,body)=>
          let val args'=List.map(fn name=>(name,L.delay(fn()=>level+1)))args
              val result=walk(level+1)(args'@environment)body
          in Ann(L.delay(fn()=>freeLevel(tag tree)environment),L.delay(fn()=>ALam(args',result)))end
       |ALet(recursive,definitions,body)=>
          let val names=binders definitions
              val maxLevel=L.delay(fn()=>freeLevel(unions(List.map tag(rhss definitions)))
                    (List.map(fn name=>(name,L.delay(fn()=>0)))names@environment))
              val rhsEnv=if recursive then List.map(fn name=>(name,maxLevel))names@environment else environment
              val right=List.map(walk level rhsEnv)(rhss definitions)
              val definitions'=List.map(fn(name,rhs)=>((name,L.delay(fn()=>tag rhs)),rhs))(ListPair.zip(names,right))
              val result=walk level(binders definitions'@environment)body
          in Ann(L.delay(fn()=>tag result),L.delay(fn()=>ALet(recursive,definitions',result)))end)
   in walk 0[](freeVars expr)end
 fun identify tree=
   let fun walk context tree=L.delay(fn()=>
          let val level=tag tree val node=payload tree
              val output=one level node
              val candidate=case node of AConst _=>false|AVar _=>false|_=>true
          in if level=context orelse not candidate then L.force output
             else ELet(false,[((named"v",L.delay(fn()=>level)),output)],variable"v")end)
       and one level node=L.delay(fn()=>case node of AConst k=>EConst k|AVar v=>EVar v
          |AAp(a,b)=>EAp(walk level a,walk level b)
          |ALam(args,body)=>
             let val(_,argumentLevel)=List.hd args
             in ELam(args,walk(L.force argumentLevel)body)end
          |ALet(recursive,definitions,body)=>ELet(recursive,
             List.map(fn(binder as(name,rhsLevel),rhs)=>(binder,walk(L.force rhsLevel)rhs))definitions,walk level body))
   in walk 0 tree end
 fun rename expr=
   let fun newBinder supply(name,info)=let val(next,name')=newName supply name in(next,(name',info))end
       fun assoc old fresh=ListPair.map(fn((a,_),(b,_))=>(a,b))(old,fresh)
       fun walk environment supply expr=case L.force expr of
          EConst k=>(supply,L.delay(fn()=>EConst k))
         |EVar name=>(supply,var(L.delay(fn()=>L.force(lookup(L.force environment)name))))
         |EAp(a,b)=>
            let val(s1,a')=walk environment supply a val(s2,b')=walk environment s1 b
            in(s2,app a' b')end
         |ELam(args,body)=>
            let val(s1,args')=mapAccum newBinder supply args
                val env=L.delay(fn()=>assoc args args'@L.force environment)
                val(s2,body')=walk env s1 body
                (* Preserve the source's returned supply, including ns1 here. *)
            in(s1,lam args' body')end
         |ELet(recursive,definitions,body)=>
            let val names=binders definitions
                val fresh=ref NONE
                val extended=L.delay(fn()=>case !fresh of SOME names'=>assoc names names'@L.force environment
                     |NONE=>raise Fail"renaming environment demanded before supply")
                val(s1,body')=walk extended supply body
                val(s2,names')=mapAccum newBinder s1 names
                val _=fresh:=SOME names'
                val rhsEnv=if recursive then extended else environment
                val(s3,right)=mapAccum(walk rhsEnv)s2(rhss definitions)
            in(s3,lett recursive(ListPair.zip(names',right))body')end
       val(_,result)=walk(L.delay(fn()=>[]))(L.delay(fn()=>0))expr
   in result end
 type floated=int L.delay*bool*(name*name expr)list
 fun install groups expr=List.foldr(fn((_,recursive,definitions),body)=>lett recursive definitions body)expr groups
 fun floatExpr expr=
   let fun walk expr=case L.force expr of EConst k=>([],L.delay(fn()=>EConst k))
         |EVar name=>([],var name)
         |EAp(a,b)=>
            let val(first,a')=walk a val(last,b')=walk b
            in(first@last,app a' b')end
         |ELam(args,body)=>
            let val(groups,body')=walk body
                val(_,level)=List.hd args
                fun here(groupLevel,_,_)=L.force groupLevel>=L.force level
                val localGroups=List.filter here groups
                val outerGroups=List.filter(not o here)groups
            in(outerGroups,lam(List.map #1 args)(install localGroups body'))end
         |ELet(recursive,definitions,body)=>
            let val(bodyGroups,body')=walk body
                fun definition prior((name,level),rhs)=
                   let val(groups,rhs')=walk rhs in(groups@prior,(name,rhs'))end
                val(rhsGroups,definitions')=mapAccum definition[]definitions
                val(_,level)=List.hd(binders definitions)
            in(rhsGroups@[(level,recursive,definitions')]@bodyGroups,body')end
       val(groups,result)=walk expr
   in install groups result end
 fun forceName name=ignore(L.force name)
 fun forceConstant(CFun name)=forceName name|forceConstant _=()
 fun forceExpr binder expr=case L.force expr of
      EConst k=>forceConstant k|EVar name=>forceName name
     |EAp(a,b)=>(forceExpr binder a;forceExpr binder b)
     |ELam(args,body)=>(List.app binder args;forceExpr binder body)
     |ELet(_,definitions,body)=>(List.app(fn(name,rhs)=>(binder name;forceExpr binder rhs))definitions;forceExpr binder body)
 fun forceAnn binder annotation expr=case L.force expr of Ann(info,node)=>
   (annotation(L.force info);
    case L.force node of AConst k=>forceConstant k|AVar name=>forceName name
     |AAp(a,b)=>(forceAnn binder annotation a;forceAnn binder annotation b)
     |ALam(args,body)=>(List.app binder args;forceAnn binder annotation body)
     |ALet(_,definitions,body)=>(List.app(fn(name,rhs)=>(binder name;forceAnn binder annotation rhs))definitions;forceAnn binder annotation body))
 fun boundaryExpr binder expr=(if strict then forceExpr binder expr else();expr)
 fun boundaryAnn binder annotation expr=(if strict then forceAnn binder annotation expr else();expr)
 fun lambdaLift expr=
   let val annotated=boundaryAnn forceName(List.app forceName)(freeVars expr)
       val abstracted=boundaryExpr forceName(abstract annotated)
       val result=collect abstracted
       val _=if strict then List.app(fn(name,args,body)=>(forceName name;List.app forceName args;forceExpr forceName body))result else()
   in result end
 fun fullyLazyLift expr=
   let fun binder(name,level)=(forceName name;ignore(L.force level))
       val separate=boundaryExpr forceName(separate expr)
       val levels=boundaryAnn binder(fn _=>())(addLevels separate)
       val mfes=boundaryExpr binder(identify levels)
       val renamed=boundaryExpr binder(rename mfes)
       val floated=boundaryExpr forceName(floatExpr renamed)
   in lambdaLift floated end
fun cases()=[("identity",app (lam [named "x"] (variable "x")) (cn (42:IntInf.int))),("capture",lett false [(named "a",cn (2:IntInf.int))] (app (lam [named "x"] (app (app (cf "+") (variable "a")) (variable "x"))) (cn (40:IntInf.int)))),("multi-lambda",app (app (lam [named "x",named "y"] (app (app (cf "+") (variable "x")) (variable "y"))) (cn (17:IntInf.int))) (cn (25:IntInf.int))),("shadow",app (app (lam [named "x"] (lam [named "x"] (variable "x"))) (cn (1:IntInf.int))) (cn (42:IntInf.int))),("unused-cycle",lett true [(named "bad",variable "bad")] (cn (42:IntInf.int))),("factorial",lett true [(named "fac",lam [named "n"] (app (app (app (cf "if") (app (app (cf "==") (variable "n")) (cn (0:IntInf.int)))) (cn (1:IntInf.int))) (app (app (cf "*") (variable "n")) (app (variable "fac") (app (app (cf "-") (variable "n")) (cn (1:IntInf.int)))))))] (app (variable "fac") (cn (6:IntInf.int)))),("fixed-program",lett true [(named "p",lam [named "a",named "b"] (lett false [(named "p",app (app (cf "-") (app (app (cf "+") (variable "a")) (variable "b"))) (cn (20:IntInf.int)))] (lett false [(named "m",lam [named "p",named "q"] (lett false [(named "g",app (app (cf "+") (variable "a")) (cn (6:IntInf.int)))] (lett false [(named "d",lam [named "pp"] (app (app (cf "+") (app (app (cf "+") (variable "pp")) (variable "q"))) (variable "p")))] (lett false [(named "c",lam [named "q"] (app (app (cf "+") (app (app (cf "-") (variable "q")) (variable "g"))) (variable "a")))] (app (app (cf "-") (app (app (cf "-") (app (variable "d") (app (app (cf "+") (cn (1:IntInf.int))) (variable "a")))) (app (variable "c") (app (app (cf "-") (variable "a")) (variable "b"))))) (variable "p"))))))] (lett true [(named "f",lam [named "a",named "b"] (app (app (variable "g") (variable "a")) (app (app (cf "+") (variable "b")) (cn (1:IntInf.int))))),(named "g",lam [named "x",named "y"] (app (app (variable "f") (variable "x")) (app (app (cf "+") (variable "y")) (variable "b"))))] (lett false [(named "h",lam [named "a",named "n"] (app (app (variable "m") (app (app (cf "+") (variable "n")) (cn (1:IntInf.int)))) (app (app (variable "f") (variable "a")) (variable "n"))))] (app (app (variable "h") (variable "a")) (variable "p")))))))] (app (app (variable "p") (cn (5:IntInf.int))) (cn (6:IntInf.int))))]
end
