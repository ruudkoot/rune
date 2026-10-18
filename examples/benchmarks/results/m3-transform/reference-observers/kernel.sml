functor BenchTransformFn(D:BENCH_SUSPEND)=
struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 type text=char F.seq
 datatype token=NUMB of text|NAME of text|SYMB of text|STR of text|PRAG of text|ERR of text|LAYOUT
 datatype defNode=Caf of text F.seq*expr|Def of text*text F.seq*expr*whereExpr
 and whereNode=Where of program|NoWhere
 and exprNode=Tail of int D.t*expr|Cons of int D.t*expr*expr
   |Map of int D.t*text*expr F.seq|Maps of int D.t*text*text*expr*expr F.seq
   |Ap of text*expr F.seq|Tuple of expr F.seq|Var of text|Lit of text
 withtype def=defNode D.t
 and whereExpr=whereNode D.t
 and expr=exprNode D.t
 and program=defNode D.t F.seq
 type quad=text*text F.seq*text*program
 fun text s=F.fromList(String.explode s)
 fun list xs=F.fromList xs
 fun empty()=F.empty()
 fun one x=F.cons(D.delay(fn()=>x),F.empty())
 fun cons x xs=F.cons(D.delay(fn()=>x),xs)
 fun number cell=D.delay(fn()=>D.force(text(String.map(fn #"~"=> #"-"|c=>c)(Int.toString(D.force cell)))))
 fun append xs ys=F.append xs ys
 fun concat texts=D.delay(fn()=>case D.force texts of F.Nil=>F.Nil
   |F.Cons(x,rest)=>D.force(append(D.force x)(concat rest)))
 fun map f xs=F.map f xs
 fun reverse xs=F.foldl(fn acc=>fn x=>cons x acc)(empty())xs
 fun head xs=case D.force xs of F.Cons(x,_)=>D.force x|F.Nil=>raise Empty
 fun tail xs=case D.force xs of F.Cons(_,rest)=>rest|F.Nil=>raise Empty
 fun null xs=case D.force xs of F.Nil=>true|_=>false
 fun foldr f initial xs=D.delay(fn()=>case D.force xs of F.Nil=>D.force initial
   |F.Cons(x,rest)=>D.force(f x(foldr f initial rest)))
 fun filter p xs=F.filter p xs
 fun compareChars xs ys=case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>0
   |(F.Nil,_)=> ~1|(_,F.Nil)=>1
   |(F.Cons(a,rest),F.Cons(b,tail))=>
       let val order=Char.ord(D.force a)-Char.ord(D.force b)
       in if order=0 then compareChars rest tail else order end
 fun equal xs ys=compareChars xs ys=0
 fun member cmp xs value=case D.force xs of F.Nil=>false
   |F.Cons(x,rest)=>cmp value(D.force x)=0 orelse member cmp rest value
 fun all p xs=case D.force xs of F.Nil=>true
   |F.Cons(x,rest)=>p(D.force x)andalso all p rest
 fun takeWhile p xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if p(D.force x)then F.Cons(x,takeWhile p rest)else F.Nil)
 fun dropWhile p xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if p(D.force x)then D.force(dropWhile p rest)else F.Cons(x,rest))
 fun fromInt n=D.delay(fn()=>n)
 fun caf vars expr=D.delay(fn()=>Caf(vars,expr))
 fun def name vars expr whereExpr=D.delay(fn()=>Def(name,vars,expr,whereExpr))
 fun whereExpr program=D.delay(fn()=>Where program)
 fun noWhere()=D.delay(fn()=>NoWhere)
 fun var name=D.delay(fn()=>Var name)
 fun lit value=D.delay(fn()=>Lit value)
 fun tuple values=D.delay(fn()=>Tuple values)
 fun ap name values=D.delay(fn()=>Ap(name,values))
 fun tailExpr label expr=D.delay(fn()=>Tail(label,expr))
 fun consExpr label state expr=D.delay(fn()=>Cons(label,state,expr))
 fun mapExpr label name values=D.delay(fn()=>Map(label,name,values))
 fun mapsExpr label first last state values=D.delay(fn()=>Maps(label,first,last,state,values))
 fun listCompare cmp xs ys=case(D.force xs,D.force ys)of(F.Nil,F.Nil)=>0
   |(F.Nil,_)=> ~1|(_,F.Nil)=>1
   |(F.Cons(a,rest),F.Cons(b,tail))=>
      let val order=cmp(D.force a)(D.force b)
      in if order=0 then listCompare cmp rest tail else order end
 fun combine []=0|combine(first::rest)=let val n=first()in if n=0 then combine rest else n end
 fun exprOrder(Tail _)=1|exprOrder(Cons _)=2|exprOrder(Map _)=3|exprOrder(Maps _)=4
   |exprOrder(Ap _)=5|exprOrder(Tuple _)=6|exprOrder(Var _)=7|exprOrder(Lit _)=8
 fun intCompare(a:int D.t)(b:int D.t)=D.force a-D.force b
 fun compareExpr x y=
   let val a=D.force x val b=D.force y
       val order=exprOrder a-exprOrder b
   in if order<>0 then order else case(a,b)of
      (Tail(p,e),Tail(q,f))=>combine[fn()=>intCompare p q,fn()=>compareExpr e f]
     |(Cons(p,s,e),Cons(q,t,f))=>combine[fn()=>intCompare p q,fn()=>compareExpr s t,fn()=>compareExpr e f]
     |(Map(p,f,args),Map(q,g,args'))=>combine[fn()=>intCompare p q,fn()=>compareChars f g,fn()=>listCompare compareExpr args args']
     |(Maps(p,f,g,s,args),Maps(q,f',g',s',args'))=>combine[
         fn()=>intCompare p q,fn()=>compareChars f f',fn()=>compareChars g g',
         fn()=>compareExpr s s',fn()=>listCompare compareExpr args args']
     |(Ap(f,args),Ap(g,args'))=>combine[fn()=>compareChars f g,fn()=>listCompare compareExpr args args']
     |(Tuple args,Tuple args')=>listCompare compareExpr args args'
     |(Var a,Var b)=>compareChars a b
     |(Lit a,Lit b)=>compareChars a b
     |_=>raise Fail"transform expression comparison invariant"end
 fun compareDef x y=case(D.force x,D.force y)of
      (Caf(args,e),Caf(args',e'))=>combine[fn()=>listCompare compareChars args args',fn()=>compareExpr e e']
     |(Caf _,Def _)=> ~1
     |(Def(f,args,e,w),Def(g,args',e',w'))=>combine[fn()=>compareChars f g,
        fn()=>listCompare compareChars args args',fn()=>compareExpr e e',fn()=>compareWhere w w']
     |(Def _,Caf _)=>1
 and compareWhere x y=case(D.force x,D.force y)of
      (Where a,Where b)=>listCompare compareDef a b|(Where _,NoWhere)=> ~1
     |(NoWhere,NoWhere)=>0|(NoWhere,Where _)=>1
 fun merge unique cmp xs ys=D.delay(fn()=>case D.force xs of F.Nil=>D.force ys
   |F.Cons(a,rest)=>(case D.force ys of F.Nil=>F.Cons(a,rest)
      |F.Cons(b,tail)=>
       let val order=cmp(D.force a)(D.force b)
       in if order<0 orelse(order=0 andalso not unique)then F.Cons(a,merge unique cmp rest ys)
          else if order=0 then F.Cons(a,merge unique cmp rest tail)
          else F.Cons(b,merge unique cmp xs tail)end))
 fun sort unique cmp xs=D.delay(fn()=>
   let val size=F.length xs val middle=size div 2
   in if size<=1 then D.force xs else D.force(merge unique cmp(sort unique cmp(F.take middle xs))(sort unique cmp(F.drop middle xs)))end)
 fun removeOne cmp value xs=D.delay(fn()=>case D.force xs of F.Nil=>F.Nil
   |F.Cons(x,rest)=>if cmp(D.force x)(D.force value)=0 then D.force rest
      else F.Cons(x,removeOne cmp value rest))
 fun remove cmp xs ys=D.delay(fn()=>case D.force ys of F.Nil=>D.force xs
   |F.Cons(y,rest)=>D.force(remove cmp(removeOne cmp y xs)rest))
 fun uniqueNames names=sort true compareChars names
 fun uniqueDefs defs=sort true compareDef defs
 fun removeNames names removed=remove compareChars names removed
 fun removeDefs defs removed=remove compareDef defs removed
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
 fun pairValue pair=D.delay(fn()=>let val(value,_)=L.force pair in D.force value end)
 fun pairCounter pair=D.delay(fn()=>let val(_,counter)=L.force pair in D.force counter end)
 fun increment q=D.delay(fn()=>D.force q+2)
 fun labelList f values reversed q=L.delay(fn()=>case D.force values of
     F.Nil=>(reverse reversed,q)
    |F.Cons(value,rest)=>let val result=f(D.force value)q
       in L.force(labelList f rest(cons(pairValue result)reversed)(pairCounter result))end)
 fun labelDef definition q=L.delay(fn()=>case D.force definition of
     Caf(names,e)=>let val result=labelExpr e q
       in(caf names(pairValue result),pairCounter result)end
    |Def(name,args,e,w)=>let val result=labelExpr e q
         val whereResult=labelWhere w(pairCounter result)
       in(def name args(pairValue result)(pairValue whereResult),pairCounter whereResult)end)
 and labelWhere wherePart q=L.delay(fn()=>case D.force wherePart of
     NoWhere=>(noWhere(),q)
    |Where program=>let val result=labelDefs program q in(whereExpr(pairValue result),pairCounter result)end)
 and labelExpr expr q=L.delay(fn()=>case D.force expr of
     Tail(_,e)=>let val result=labelExpr e(increment q)
       in(tailExpr q(pairValue result),pairCounter result)end
    |Cons(_,s,e)=>let val stream=labelExpr e(increment q)
         val state=labelExpr s(pairCounter stream)
       in(consExpr q(pairValue state)(pairValue stream),pairCounter state)end
    |Map(_,name,args)=>let val result=labelExprs args(increment q)
       in(mapExpr q name(pairValue result),pairCounter result)end
    |Maps(_,f,g,s,args)=>let val result=labelExprs args(increment q)
         val state=labelExpr s(pairCounter result)
       in(mapsExpr q f g(pairValue state)(pairValue result),pairCounter state)end
    |Ap(name,args)=>let val result=labelExprs args q in(ap name(pairValue result),pairCounter result)end
    |Tuple args=>let val result=labelExprs args q in(tuple(pairValue result),pairCounter result)end
    |_=>(expr,q))
 and labelDefs program q=labelList labelDef program(empty())q
 and labelExprs exprs q=labelList labelExpr exprs(empty())q

 fun label program=pairValue(labelDefs program(fromInt 1))
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
 fun range first last=D.delay(fn()=>
   let val a=D.force first val b=D.force last
   in if a>b then F.Nil else F.Cons(D.delay(fn()=>a),range(D.delay(fn()=>a+1))last)end)
 fun expressionName p expr=D.delay(fn()=>D.force(
   case D.force expr of Var name=>name|_=>append(text"xxa")(number p)))
 fun expressionNames p args=
   map(fn(index,e)=>expressionName(fromInt index)e)
      (zip(range p(D.delay(fn()=>D.force p+F.length args-1)))args)
 fun t1 program=concat(map t2 program)
 and t2 definition=D.delay(fn()=>D.force(
   case singleCaf definition of NONE=>one definition|SOME(name,e)=>
    (case D.force e of
       Tail(p,child)=>let val w=expressionName p child
         in cons(caf(one name)(tailExpr p(var w)))(t2(caf(one w)child))end
      |Cons(p,s,child)=>let val w=expressionName p child
         in cons(caf(one name)(consExpr p s(var w)))(t2(caf(one w)child))end
      |Map(p,f,args)=>let val names=expressionNames p args
         in cons(caf(one name)(mapExpr p f(map var names)))
            (concat(map(fn(v,e)=>t2(caf(one v)e))(zip names args)))end
      |Maps(p,f,g,s,args)=>let val names=expressionNames p args
         in cons(caf(one name)(mapsExpr p f g s(map var names)))
            (concat(map(fn(v,e)=>t2(caf(one v)e))(zip names args)))end
      |Var other=>if equal name other then empty()else one(caf(one name)(var other))
      |_=>one definition)))
 fun t3 program=concat(map t4 program)
 and t4 definition=D.delay(fn()=>D.force(
   case singleCaf definition of NONE=>one definition|SOME(name,e)=>
     case D.force e of Maps(p,f,g,s,args)=>
       let val y=append(text"xxb")(number p)val z=append(text"xxc")(number p)
       in list[caf(one name)(mapExpr p f(cons(var y)args)),
         caf(one y)(consExpr p s(var z)),caf(one z)(mapExpr p g(cons(var y)args))]end
      |_=>one definition))
 fun consesTailsMapsRest program=
   let fun select tag definition=case singleCaf definition of NONE=>NONE|SOME(name,e)=>
         case(D.force e,tag)of
           (Cons(p,s,x),0)=>SOME(caf(one name)(consExpr p s x))
          |(Tail(p,x),1)=>SOME(caf(one name)(tailExpr p x))
          |(Map(p,f,args),2)=>SOME(caf(one name)(mapExpr p f args))
          |_=>NONE
       val conses=choose(select 0)program
       val tails=choose(select 1)program
       val maps=choose(select 2)program
   in(conses,tails,maps,removeDefs(removeDefs(removeDefs program conses)tails)maps)end
 fun t6 program=
   let val(conses,tails,maps,_)=consesTailsMapsRest(use program)
       fun fromCons definition=case singleCaf definition of SOME(name,e)=>
            (case D.force e of Cons(_,s,x)=>(name,s,x)|_=>raise Fail"transform cons partition")
         |NONE=>raise Fail"transform cons partition"
       val values=map fromCons conses
       val names=map(fn(name,_,_)=>name)values
       val states=map(fn(_,state,_)=>state)values
       val next=map(fn(_,_,expr)=>expr)values
       val parameters=uniqueNames(append(free(append conses(append tails maps)))(bound tails))
       val selector=append(text"sel_")(number(D.delay(fn()=>F.length states)))
       val identity=append(text"id_")(number(D.delay(fn()=>F.length parameters+1)))
       val additions=map(fn definition=>case singleCaf definition of SOME(name,e)=>
            (case D.force e of Map(_,f,args)=>caf(one name)(ap f args)|_=>raise Fail"transform map partition")
          |NONE=>raise Fail"transform map partition")maps
       val state=text"s"
   in append(list[
       caf(one(text"output1"))(mapExpr(fromInt 1)selector(one(mapsExpr(fromInt 1)identity(text"nextstate")(tuple states)(map var parameters)))),
       def(text"nextstate")(cons state parameters)(tuple next)(whereExpr(cons(caf names(var state))additions))])program end
 val missing=text"?"
 val missingExpr=lit missing
 val missingArgs=one missingExpr
 val zero:int D.t=fromInt 0
 fun findMap wanted prefix program=L.delay(fn()=>case D.force program of
      F.Nil=>(false,zero,missing,missingArgs,prefix)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=L.force(findMap wanted(cons definition prefix)rest)
       in case singleCaf original of NONE=>continue original|SOME(name,e)=>
         case D.force e of Map(p,f,args)=>if equal name wanted then(true,p,f,args,append prefix rest)
           else continue(caf(one name)(mapExpr p f args))
          |_=>continue original end)
 fun findCons wanted prefix program=L.delay(fn()=>case D.force program of
      F.Nil=>(false,zero,missingExpr,missingExpr,prefix)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=L.force(findCons wanted(cons definition prefix)rest)
       in case singleCaf original of NONE=>continue original|SOME(name,e)=>
         case D.force e of Cons(p,s,x)=>if equal name wanted then(true,p,s,x,append prefix rest)
           else continue(caf(one name)(consExpr p s x))
          |_=>continue original end)
 fun notIn(a,b)pairs=case D.force pairs of F.Nil=>true
   |F.Cons(pair,rest)=>let val(x,y)=D.force pair
       in if D.force a=D.force x andalso D.force b=D.force y then false else notIn(a,b)rest end
 fun t5 program=passA(empty())program(empty())(fromInt 1)
 and passA prefix program pairs n=D.delay(fn()=>case D.force program of
      F.Nil=>D.force(passB(empty())prefix pairs n)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue()=D.force(passA(cons original prefix)rest pairs n)
       in case singleCaf original of NONE=>continue()|SOME(name,e)=>
         if not(equal name output)then continue()else
          case D.force e of Map(k,f,args)=>
            let val v=append(text"xxv")(number n)
                val w=append(text"xxw")(number(D.delay(fn()=>D.force n+1)))
                val new=cons(caf(one output)(consExpr k(ap f(map(fn x=>ap(text"hd")(one x))args))(var v)))
                  (cons(caf(one v)(tailExpr k(var w)))
                    (cons(caf(one w)(mapExpr k f args))(append prefix rest)))
            in D.force(passA(empty())new pairs(D.delay(fn()=>D.force n+2)))end
           |_=>continue()end)
 and passB prefix program pairs n=D.delay(fn()=>case D.force program of
      F.Nil=>D.force(passC(empty())prefix pairs n)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=D.force(passB(cons definition prefix)rest pairs n)
       in case singleCaf original of NONE=>continue original|SOME(name,e)=>
         if not(equal name output)then continue original else case D.force e of Tail(k,child)=>
          (case D.force child of Var w=>
             let val(ok,j,s,x,all)=L.force(findCons w(empty())(append prefix rest))
             in if ok then
                let val new=substitute(cons(caf(one w)(consExpr j s(var output)))all)(one(output,x))
                in D.force(passA(empty())new pairs n)end
               else continue(caf(one output)(tailExpr k(var w)))end
           |_=>continue original)
          |_=>continue original end)
 and passC prefix program pairs n=D.delay(fn()=>case D.force program of
      F.Nil=>D.force(passD(empty())prefix pairs n)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=D.force(passC(cons definition prefix)rest pairs n)
       in case singleCaf original of NONE=>continue original|SOME(v,e)=>
          case D.force e of Tail(k,child)=>(case D.force child of Var w=>
             let val(ok,j,s,x,all)=L.force(findCons w(empty())(append prefix rest))
             in if ok then
                let val new=substitute(cons(caf(one w)(consExpr j s x))all)(one(v,x))
                in D.force(passA(empty())new pairs n)end
               else continue(caf(one v)(tailExpr k(var w)))end
           |_=>continue original)
          |_=>continue original end)
 and passD prefix program pairs n=D.delay(fn()=>case D.force program of
      F.Nil=>D.force(append(empty())prefix)
     |F.Cons(definition,rest)=>
       let val original=D.force definition
           fun continue definition=D.force(passD(cons definition prefix)rest pairs n)
       in case singleCaf original of NONE=>continue original|SOME(v,e)=>
          case D.force e of Tail(k,child)=>(case D.force child of Var w=>
             let val(ok,j,f,args,all)=L.force(findMap w(empty())(append prefix rest))
             in if ok andalso notIn(j,k)pairs then
                let val last=D.delay(fn()=>D.force n+F.length args-1)
                    val names=map(fn i=>append(text"xxy")(number(fromInt i)))(range n last)
                    val new=cons(caf(one w)(consExpr j(ap f(map(fn x=>ap(text"hd")(one x))args))(var v)))
                      (cons(caf(one v)(mapExpr j f(map var names)))
                         (append(map(fn(y,x)=>caf(one y)(tailExpr k x))(zip names args))all))
                in D.force(passA(empty())new(cons(j,k)pairs)(D.delay(fn()=>D.force last+1)))end
               else continue(caf(one v)(tailExpr k(var w)))end
           |_=>continue original)
          |_=>continue original end)
 datatype 'a controlNode=CEmpty|CNext of 'a L.delay*'a controlNode L.delay
 type 'a control='a controlNode L.delay
 type tokenStream=token control
 fun cEmpty()=L.delay(fn()=>CEmpty)
 fun cOne value=L.delay(fn()=>CNext(L.delay(fn()=>value),cEmpty()))
 fun cAppend first last=L.delay(fn()=>case L.force first of CEmpty=>L.force last
   |CNext(value,rest)=>CNext(value,cAppend rest last))
 fun cTake 0 _=cEmpty()
   |cTake n values=L.delay(fn()=>case L.force values of CEmpty=>CEmpty
     |CNext(value,rest)=>CNext(value,cTake(n-1)rest))
 fun cMap f values=L.delay(fn()=>case L.force values of CEmpty=>CEmpty
   |CNext(value,rest)=>CNext(L.delay(fn()=>f(L.force value)),cMap f rest))
 fun cBind f values=L.delay(fn()=>case L.force values of CEmpty=>CEmpty
   |CNext(value,rest)=>L.force(cAppend(f(L.force value))(cBind f rest)))
 fun cHead values=case L.force values of CNext(value,_)=>L.force value|CEmpty=>raise Empty
 fun cDefer f=L.delay(fn()=>L.force(f()))
 fun letter c=(c>= #"a"andalso c<= #"z")orelse(c>= #"A"andalso c<= #"Z")
 fun digit c=c>= #"0"andalso c<= #"9"
 fun letgit c=letter c orelse digit c orelse c= #"_"orelse c= #"'"
 fun realdigit c=digit c orelse List.exists(fn x=>x=c)[#"+",#"-",#"e",#"."]
 fun substring predicate reversed chars=L.delay(fn()=>case D.force chars of
      F.Nil=>(reverse reversed,empty())
     |F.Cons(c,rest)=>if predicate(D.force c)then L.force(substring predicate(F.cons(c,reversed))rest)
        else(reverse reversed,F.cons(c,rest)))
 fun splitText pair=D.delay(fn()=>let val(value,_)=L.force pair in D.force value end)
 fun splitRest pair=D.delay(fn()=>let val(_,rest)=L.force pair in D.force rest end)
 fun prefix chars literal=
   let fun loop _ []=true
         |loop chars(c::cs)=case D.force chars of F.Nil=>false
            |F.Cons(value,rest)=>D.force value=c andalso loop rest cs
   in loop chars(String.explode literal)end
 val operatorNames=["(:)","(++)","(+)","(-)","(--)","(*)","(/)","(~)"]
 fun firstOperator chars []=NONE
   |firstOperator chars(name::rest)=if prefix chars name then SOME name else firstOperator chars rest
 fun lexer chars=L.delay(fn()=>case D.force chars of F.Nil=>CEmpty
   |F.Cons(value,rest)=>
    let val c=D.force value
        fun emit token tail=CNext(L.delay(fn()=>token),lexer tail)
    in if c= #" "orelse c= #"\t"orelse c= #"\n"orelse c= #"\012"then L.force(lexer rest)
       else if c= #"|"andalso prefix chars"||"then L.force(lexer(dropWhile(fn c=>c<> #"\n")(F.drop 2 chars)))
       else if c= #"("then
         (case firstOperator chars operatorNames of SOME name=>emit(NAME(text name))(F.drop(String.size name)chars)
           |NONE=>emit(SYMB(text"("))rest)
       else if List.exists(fn x=>x=c)[#")",#",",#";",#"="]then emit(SYMB(text(String.str c)))rest
       else if c= #"#"then emit(NAME(text"#"))rest
       else if c= #"\""then
          let val scanned=substring(fn c=>c<> #"\"")(empty())rest
          in CNext(L.delay(fn()=>STR(splitText scanned)),cDefer(fn()=>lexer(tail(splitRest scanned))))end
       else if c= #"%"then
          let val scanned=substring letgit(empty())rest
          in CNext(L.delay(fn()=>PRAG(splitText scanned)),lexer(splitRest scanned))end
       else if letter c then
          let val scanned=substring letgit(one c)rest
          in CNext(L.delay(fn()=>NAME(splitText scanned)),lexer(splitRest scanned))end
       else if digit c then
          let val scanned=substring realdigit(one c)rest
          in CNext(L.delay(fn()=>NUMB(splitText scanned)),lexer(splitRest scanned))end
       else emit(ERR(append(text"illegal char ")(one c)))rest
    end)
 fun findPragma wanted reversed tokens=D.delay(fn()=>
   case L.force tokens of CEmpty=>D.force(reverse reversed)
    |CNext(value,rest)=>(case L.force value of PRAG name=>
       (case L.force rest of CNext(next,tail)=>(case L.force next of STR argument=>
           D.force(findPragma wanted(if equal wanted name then cons argument reversed else reversed)tail)
         |_=>D.force(findPragma wanted reversed rest))
        |CEmpty=>D.force(findPragma wanted reversed rest))
      |_=>D.force(findPragma wanted reversed rest)))
 fun dropPragma tokens=L.delay(fn()=>case L.force tokens of CEmpty=>CEmpty
   |CNext(value,rest)=>(case L.force value of PRAG _=>
        (case L.force rest of CNext(_,tail)=>L.force(dropPragma tail)|CEmpty=>CNext(value,dropPragma rest))
     |_=>CNext(value,dropPragma rest)))
 fun tokenOrder(NUMB _)=1|tokenOrder(NAME _)=2|tokenOrder(SYMB _)=3|tokenOrder(STR _)=4
   |tokenOrder(PRAG _)=5|tokenOrder(ERR _)=6|tokenOrder LAYOUT=7
 fun tokenText(NUMB value)=value|tokenText(NAME value)=value|tokenText(SYMB value)=value
   |tokenText(STR value)=value|tokenText(PRAG value)=value|tokenText(ERR value)=value
   |tokenText LAYOUT=empty()
 fun tokenCompare first last=
   let val order=tokenOrder first-tokenOrder last
   in if order=0 then compareChars(tokenText first)(tokenText last)else order end
 type 'a pattern=tokenStream->('a*tokenStream)control
 fun pure value input=cOne(value,input)
 fun patMatch predicate convert input=L.delay(fn()=>case L.force input of CEmpty=>CEmpty
   |CNext(value,rest)=>let val token=L.force value
       in if predicate token then CNext(L.delay(fn()=>(D.delay(fn()=>D.force(convert token)),rest)),cEmpty())else CEmpty end)
 fun patAlt first last input=cAppend(cDefer(fn()=>first input))(cDefer(fn()=>last input))
 fun patFirst first last input=cTake 1(patAlt first last input)
 fun patSeq join first last input=
   cBind(fn(a,rest)=>cMap(fn(b,tail)=>(D.delay(fn()=>D.force(join a b)),tail))(last rest))(cDefer(fn()=>first input))
 fun patApp convert parser input=cMap(fn(value,rest)=>(D.delay(fn()=>D.force(convert value)),rest))(cDefer(fn()=>parser input))
 fun semanticCons first last=F.cons(D.delay(fn()=>first),last)
 fun patRepeat(parser:'a D.t pattern)=
   let val cache:('a D.t F.seq pattern)option ref=ref NONE
       fun loop input=(case !cache of SOME pattern=>pattern
          |NONE=>let val pattern=patFirst(patSeq semanticCons parser loop)(pure(empty()))
                 in cache:=SOME pattern;pattern end)input
   in loop end
 fun patPlus parser=patSeq semanticCons parser(patRepeat parser)
 fun patAlts []=(fn _=>cEmpty())
   |patAlts(first::rest)=patFirst first(patAlts rest)
 fun patSeqs []=pure(empty())
   |patSeqs(first::rest)=patSeq semanticCons first(patSeqs rest)
 fun literalToken token=case token of NUMB name=>lit name|NAME name=>lit name|SYMB name=>lit name
   |_=>raise Match
 fun variableToken token=case token of NAME name=>var name|SYMB name=>var name|_=>raise Match
 fun literal kind name=patMatch(fn token=>tokenCompare token(kind(text name))=0)literalToken
 val pClose:expr pattern=literal SYMB")"
 val pComma:expr pattern=literal SYMB","
 val pEq:expr pattern=literal SYMB"="
 val pCons:expr pattern=literal NAME"(:)"
 val pTail:expr pattern=literal NAME"tl"
 val pMap:expr pattern=literal NAME"map"
 val pMaps:expr pattern=literal NAME"maps"
 val pOpen:expr pattern=literal SYMB"("
 val pSemi:expr pattern=literal SYMB";"
 val pIdent:expr pattern=patMatch(fn NAME _=>true|_=>false)variableToken
 val pNumber:expr pattern=patMatch(fn NUMB _=>true|_=>false)literalToken
 fun item fields index=F.nth fields index
 fun fieldsCount size fields=if F.length fields=size then()else raise Match
 fun varName value=case D.force value of Var name=>name|_=>raise Match
 fun tupleValues value=case D.force value of Tuple values=>values|_=>raise Match
 val cacheProgram:program pattern option ref=ref NONE
 val cacheCaf:def pattern option ref=ref NONE
 val cacheDef:def pattern option ref=ref NONE
 val cacheExpr:expr pattern option ref=ref NONE
 val cacheSimpleList:expr pattern option ref=ref NONE
 val cacheIdentList:expr pattern option ref=ref NONE
 val cacheTail:expr pattern option ref=ref NONE
 val cacheCons:expr pattern option ref=ref NONE
 val cacheMap:expr pattern option ref=ref NONE
 val cacheMaps:expr pattern option ref=ref NONE
 val cacheAp:expr pattern option ref=ref NONE
 val cacheSimple:expr pattern option ref=ref NONE
 val cachePack:expr pattern option ref=ref NONE
 val cacheTuple:expr pattern option ref=ref NONE
 val cacheTupleComma:expr F.seq pattern option ref=ref NONE
 fun cached cache build input=(case !cache of SOME parser=>parser
   |NONE=>let val parser=build()in cache:=SOME parser;parser end)input
 fun pProgram input=cached cacheProgram(fn()=>patPlus(patAlts[pCaf,pDef]))input
 and pCaf input=cached cacheCaf(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 4 fields;
        Caf(one(varName(item fields 0)),item fields 2)))
   in patApp build(patSeqs[pIdent,pEq,pExpr,pSemi])end)input
 and pDef input=cached cacheDef(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 5 fields;
        Def(varName(item fields 0),
          choose(fn e=>case D.force e of Var name=>SOME name|_=>NONE)(tupleValues(item fields 1)),item fields 3,noWhere())))
   in patApp build(patSeqs[pIdent,pIdentList,pEq,pExpr,pSemi])end)input
 and pExpr input=cached cacheExpr(fn()=>patAlts[pTailExpr,pConsExpr,pMapExpr,pMapsExpr,pApExpr,pSimple])input
 and pSimpleList input=cached cacheSimpleList(fn()=>patApp tuple(patPlus pSimple))input
 and pIdentList input=cached cacheIdentList(fn()=>patApp tuple(patPlus pIdent))input
 and pTailExpr input=cached cacheTail(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 2 fields;Tail(fromInt 1,item fields 1)))
   in patApp build(patSeqs[pTail,pExpr])end)input
 and pConsExpr input=cached cacheCons(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 3 fields;Cons(fromInt 1,item fields 1,item fields 2)))
   in patApp build(patSeqs[pCons,pSimple,pExpr])end)input
 and pMapExpr input=cached cacheMap(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 3 fields;
        Map(fromInt 1,varName(item fields 1),tupleValues(item fields 2))))
   in patApp build(patSeqs[pMap,pIdent,pSimpleList])end)input
 and pMapsExpr input=cached cacheMaps(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 5 fields;
        Maps(fromInt 1,varName(item fields 1),varName(item fields 2),item fields 3,tupleValues(item fields 4))))
   in patApp build(patSeqs[pMaps,pIdent,pIdent,pSimple,pSimpleList])end)input
 and pApExpr input=cached cacheAp(fn()=>
   let fun build fields=D.delay(fn()=>(fieldsCount 2 fields;
        Ap(varName(item fields 0),tupleValues(item fields 1))))
   in patApp build(patSeqs[pIdent,pSimpleList])end)input
 and pSimple input=cached cacheSimple(fn()=>patAlts[pIdent,pNumber,pPack])input
 and pPack input=cached cachePack(fn()=>
    patApp(fn fields=>D.delay(fn()=>D.force(item fields 1)))(patSeqs[pOpen,patAlts[pTuple,pExpr],pClose]))input
 and pTuple input=cached cacheTuple(fn()=>
   patSeq(fn first=>fn last=>tuple(append first(one last)))pTupleComma pExpr)input
 and pTupleComma input=cached cacheTupleComma(fn()=>
    patPlus(patApp(fn fields=>D.delay(fn()=>(fieldsCount 2 fields;D.force(item fields 0))))(patSeqs[pExpr,pComma])))input
 fun parse tokens=D.delay(fn()=>let val(result,_)=cHead(pProgram tokens)in D.force result end)
 fun cat values=concat(list values)
 fun separated render separator values=D.delay(fn()=>case D.force values of F.Nil=>F.Nil
   |F.Cons(x,rest)=>D.force(append(render(D.force x))(concat(map(fn x=>append separator(render x))rest))))
 fun indent values=D.delay(fn()=>case D.force values of F.Nil=>F.Nil
   |F.Cons(c,rest)=>if D.force c= #"\n"then
       if null rest then F.Cons(c,empty())
       else F.Cons(c,cons #" "(cons #" "(indent rest)))
     else F.Cons(c,indent rest))
 fun printProgram program=separated printDef(text"\n")program
 and printDef definition=D.delay(fn()=>D.force(
   case D.force definition of
      Caf(vars,expr)=>
       if not(null vars)andalso null(tail vars)then cat[head vars,text"\t= ",printExpr expr,text";"]
       else cat[text"(",separated(fn v=>v)(text",")vars,text")\t= ",printExpr expr,text";"]
     |Def(name,vars,expr,wherePart)=>
       (case D.force wherePart of NoWhere=>cat[name,text" ",separated(fn v=>v)(text" ")vars,text"\t= ",printExpr expr,text";"]
        |Where definitions=>cat[name,text" ",separated(fn v=>v)(text" ")vars,text"\n= ",printExpr expr,
           indent(cat[text"\nwhere\n",printProgram definitions]),text";"])))
 and printExpr expr=D.delay(fn()=>D.force(
   case D.force expr of
      Tail(_,e)=>cat[text"(tl ",printExpr e,text")"]
     |Cons(_,state,e)=>cat[text"((:) ",printExpr state,text" ",printExpr e,text")"]
     |Map(_,name,args)=>cat[text"(map_",number(fromInt(F.length args)),text" ",name,text" ",printExprs args,text")"]
     |Maps(_,first,last,state,args)=>cat[text"(maps_",number(fromInt(F.length args)),text" ",first,text" ",last,
         text" ",printExpr state,text" ",printExprs args,text")"]
     |Ap(name,args)=>cat[text"(",name,text" ",printExprs args,text")"]
     |Tuple values=>if null values then text"()"else
         if null(tail values)then printExpr(head values)
         else cat[text"(",separated printExpr(text",")values,text")"]
     |Var name=>name|Lit value=>value))
 and printExprs exprs=separated printExpr(text" ")exprs
 fun quote value="\""^String.translate(fn #"\""=>"\\\""| #"\\"=>"\\\\"| #"\n"=>"\\n"| #"\r"=>"\\r"| #"\t"=>"\\t"|c=>String.str c)value^"\""
 fun showText value=String.implode(F.toList value)
 fun jsonText value=quote(showText value)
 fun arr values="["^String.concatWith","values^"]"
 fun dumpList render values=case D.force values of F.Nil=>arr[quote"[]"]
   |F.Cons(x,rest)=>arr[quote"(:)",render(D.force x),dumpList render rest]
 fun dumpExpr expr=case D.force expr of
     Tail(p,e)=>arr[quote"F_Tail",Int.toString(D.force p),dumpExpr e]
    |Cons(p,s,e)=>arr[quote"F_Cons",Int.toString(D.force p),dumpExpr s,dumpExpr e]
    |Map(p,name,args)=>arr[quote"F_Map",Int.toString(D.force p),jsonText name,dumpList dumpExpr args]
    |Maps(p,f,g,s,args)=>arr[quote"F_Maps",Int.toString(D.force p),jsonText f,jsonText g,dumpExpr s,dumpList dumpExpr args]
    |Ap(name,args)=>arr[quote"F_Ap",jsonText name,dumpList dumpExpr args]
    |Tuple args=>arr[quote"F_Tuple",dumpList dumpExpr args]
    |Var name=>arr[quote"F_Var",jsonText name]|Lit value=>arr[quote"F_Lit",jsonText value]
 fun dumpDef definition=case D.force definition of
      Caf(args,e)=>arr[quote"F_Caf",dumpList jsonText args,dumpExpr e]
     |Def(name,args,e,w)=>arr[quote"F_Def",jsonText name,dumpList jsonText args,dumpExpr e,dumpWhere w]
 and dumpWhere w=case D.force w of NoWhere=>arr[quote"C_NoWhere"]
    |Where program=>arr[quote"F_Where",dumpList dumpDef program]
 fun dumpProgram program=dumpList dumpDef program

 fun dumpToken token=case token of NUMB value=>arr[quote"F_NUMB",jsonText value]
   |NAME value=>arr[quote"F_NAME",jsonText value]|SYMB value=>arr[quote"F_SYMB",jsonText value]
   |STR value=>arr[quote"F_STR",jsonText value]|PRAG value=>arr[quote"F_PRAG",jsonText value]
   |ERR value=>arr[quote"F_ERR",jsonText value]|LAYOUT=>arr[quote"C_LAYOUT"]
 fun dumpTokens tokens=case L.force tokens of CEmpty=>arr[quote"[]"]
   |CNext(value,rest)=>arr[quote"(:)",dumpToken(L.force value),dumpTokens rest]
end
