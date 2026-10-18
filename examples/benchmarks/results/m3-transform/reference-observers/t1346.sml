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
