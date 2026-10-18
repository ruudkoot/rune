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
end
