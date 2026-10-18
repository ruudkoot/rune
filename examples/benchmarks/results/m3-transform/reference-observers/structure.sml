 fun choose f values=D.delay(fn()=>case D.force values of F.Nil=>F.Nil
   |F.Cons(x,rest)=>(case f(D.force x)of NONE=>D.force(choose f rest)
      |SOME value=>F.Cons(D.delay(fn()=>value),choose f rest)))
 fun flatMap f values=concat(map f values)
 fun singleCaf definition=case D.force definition of
     Caf(names,e)=>(case D.force names of F.Cons(name,rest)=>if null rest then SOME(D.force name,e)else NONE|F.Nil=>NONE)
    |_=>NONE
 fun cafs program=choose(fn definition=>case singleCaf definition of SOME(name,e)=>SOME(caf(one name)e)|NONE=>NONE)program
 fun vars expr=D.delay(fn()=>D.force(
   case D.force expr of Tail(_,e)=>vars e|Cons(_,_,e)=>vars e
    |Map(_,_,args)=>concat(map vars args)|Maps(_,_,_,_,args)=>concat(map vars args)
    |Ap(_,args)=>concat(map vars args)|Tuple args=>concat(map vars args)
    |Var name=>one name|Lit _=>empty()))
 fun rhsVars program=uniqueNames(concat(choose(fn definition=>case D.force definition of Caf(_,e)=>SOME(vars e)|_=>NONE)program))
 fun bound program=uniqueNames(choose(fn definition=>case singleCaf definition of SOME(name,_)=>SOME name|NONE=>NONE)program)
 fun free program=removeNames(rhsVars program)(bound program)
 fun unused program=removeNames(bound program)(rhsVars program)
 fun substitute program environment=map(fn definition=>subDef definition environment)program
 and subDef definition environment=D.delay(fn()=>case D.force definition of
     Caf(names,e)=>Caf(names,subExpr e environment)
    |Def(name,args,e,w)=>Def(name,args,subExpr e environment,subWhere w environment))
 and subWhere wherePart environment=D.delay(fn()=>case D.force wherePart of NoWhere=>NoWhere
    |Where program=>Where(substitute program environment))
 and subExpr expr environment=D.delay(fn()=>case D.force expr of
     Tail(p,e)=>Tail(p,subExpr e environment)
    |Cons(p,s,e)=>Cons(p,subExpr s environment,subExpr e environment)
    |Map(p,name,args)=>Map(p,name,map(fn e=>subExpr e environment)args)
    |Maps(p,f,g,s,args)=>Maps(p,f,g,subExpr s environment,map(fn e=>subExpr e environment)args)
    |Ap(name,args)=>Ap(name,map(fn e=>subExpr e environment)args)
    |Tuple args=>Tuple(map(fn e=>subExpr e environment)args)
    |Lit value=>Lit value
    |Var name=>
       let val matches=map #2(filter(fn(other,_)=>equal other name)environment)
       in if null matches then Var name else D.force(head matches)end)
 val output=text"output"
 fun replacements program=
   let fun selects want definition=case singleCaf definition of NONE=>NONE|SOME(name,e)=>
        (case D.force e of Var _=>if equal name output=want then SOME(caf(one name)e)else NONE|_=>NONE)
       val equalities=choose(selects false)program
       val outputs=choose(selects true)program
       fun pair definition=case singleCaf definition of SOME pair=>pair|NONE=>raise Fail"transform replacement invariant"
   in(map pair equalities,map pair outputs,removeDefs(removeDefs program equalities)outputs)end
 fun eqDef definition=D.delay(fn()=>case D.force definition of
     Caf(names,e)=>Caf(names,e)
    |Def(name,args,e,w)=>(case D.force w of NoWhere=>Def(name,args,e,w)
       |Where definitions=>
           let val(reps,_,rest)=replacements definitions
           in Def(name,args,subExpr e reps,whereExpr(substitute rest reps))end))
 fun replaceOutput newName program=D.delay(fn()=>case D.force program of F.Nil=>F.Nil
   |F.Cons(definition,rest)=>
      (case singleCaf(D.force definition)of NONE=>raise Fail"transform output replacement invariant"
       |SOME(oldName,e)=>if equal oldName newName then
            F.Cons(D.delay(fn()=>caf(one output)e),rest)
         else F.Cons(D.delay(fn()=>caf(one oldName)e),replaceOutput newName rest)))
 fun equalities program=D.delay(fn()=>
   let val(reps,outs,rest)=replacements program
   in if null outs then D.force(substitute(map eqDef rest)reps)
      else case D.force outs of F.Cons(pair,tail)=>
        if not(null tail)then raise Fail"transform output alias invariant"
        else let val(name,e)=D.force pair
             in if not(equal name output)then raise Fail"transform output alias name"
                else case D.force e of Var newName=>
                   D.force(substitute(map eqDef(replaceOutput newName rest))
                      (append reps(one(newName,var output))))
                 |_=>raise Fail"transform output alias expression"end
       |_=>raise Fail"transform output alias invariant"end)
 fun cafSort program=D.delay(fn()=>case D.force program of F.Nil=>F.Nil
   |F.Cons(definition,rest)=>
      (case singleCaf(D.force definition)of NONE=>raise Fail"transform CAF-sort invariant"
       |SOME(name,e)=>
        let fun select order definition=case singleCaf definition of NONE=>NONE|SOME(other,rhs)=>
              if order(compareExpr rhs e)then SOME(caf(one other)rhs)else NONE
            val less=choose(select(fn n=>n<0))rest
            val greater=choose(select(fn n=>n>0))rest
            val same=choose(fn definition=>case singleCaf definition of NONE=>NONE|SOME(other,rhs)=>
                 if compareExpr rhs e=0 then SOME other else NONE)rest
            val names=uniqueNames(cons name same)
            val first=head names
            val aliases=map(fn name=>caf(one name)(var first))(tail names)
        in D.force(append(cafSort less)(append(cons(caf(one first)e)aliases)(cafSort greater)))end))
 fun sorted program=
   let val constants=cafs program val rest=removeDefs program constants
   in equalities(append(cafSort constants)(uniqueDefs rest))end
 fun use program=useProgram(one output)program
 and useProgram always program=
   let val constants=cafs program val rest=removeDefs program constants
       val used=append always(removeNames(uniqueNames(append always(rhsVars constants)))always)
       fun matching name=choose(fn definition=>case singleCaf definition of NONE=>NONE|SOME(other,e)=>
           if equal other name then SOME(caf(one other)e)else NONE)program
   in map usedDef(append(flatMap matching used)rest)end
 and usedDef definition=D.delay(fn()=>case D.force definition of
      Caf(names,e)=>Caf(names,e)
     |Def(name,args,e,w)=>(case D.force w of NoWhere=>Def(name,args,e,w)
        |Where program=>Def(name,args,e,whereExpr(useProgram(empty())program))))
