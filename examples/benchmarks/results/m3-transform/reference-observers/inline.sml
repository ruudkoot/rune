 fun zip xs ys=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>(case D.force ys of F.Nil=>F.Nil
      |F.Cons(y,tail)=>F.Cons(D.delay(fn()=>(D.force x,D.force y)),zip rest tail)))
 fun inline program=
   let val candidates=choose(fn definition=>case D.force definition of
         Def(name,args,e,w)=>(case D.force w of NoWhere=>SOME(def name args e(noWhere()))|_=>NONE)
        |_=>NONE)program
   in map(fn definition=>inlineDef definition(removeDefs candidates(one definition)))program end
 and inlineDef definition environment=D.delay(fn()=>case D.force definition of
     Caf(names,e)=>Caf(names,inlineExpr e environment)
    |Def(name,args,e,w)=>Def(name,args,inlineExpr e environment,inlineWhere w environment))
 and inlineWhere wherePart environment=D.delay(fn()=>case D.force wherePart of NoWhere=>NoWhere
    |Where program=>Where(map(fn definition=>inlineDef definition environment)program))
 and inlineExpr expr environment=D.delay(fn()=>case D.force expr of
     Tail(p,e)=>Tail(p,inlineExpr e environment)
    |Cons(p,s,e)=>Cons(p,inlineExpr s environment,inlineExpr e environment)
    |Map(p,name,args)=>Map(p,name,map(fn e=>inlineExpr e environment)args)
    |Maps(p,f,g,s,args)=>Maps(p,f,g,inlineExpr s environment,map(fn e=>inlineExpr e environment)args)
    |Tuple args=>Tuple(map(fn e=>inlineExpr e environment)args)
    |Lit value=>Lit value|Var name=>Var name
    |Ap(name,args)=>
       let val matches=choose(fn definition=>case D.force definition of
             Def(other,params,body,w)=>(case D.force w of NoWhere=>
               if equal other name andalso F.length params=F.length args then SOME(zip params args,body)else NONE|_=>NONE)
            |_=>NONE)environment
       in if null matches then Ap(name,map(fn e=>inlineExpr e environment)args)
          else let val(subs,body)=head matches in D.force(subExpr body subs)end end)
