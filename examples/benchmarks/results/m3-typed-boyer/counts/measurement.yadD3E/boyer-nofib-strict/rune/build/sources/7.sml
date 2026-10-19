functor BenchTypedBoyerFn (D : BENCH_SUSPEND) =
struct
  structure L=BenchLazy
  structure S=BenchStream
  datatype termNode = Var of int | Fun of int * argsNode D.t * (termNode D.t * termNode D.t) S.stream
  and argsNode = ANil | ACons of termNode D.t * argsNode D.t
  type term=termNode D.t
  type environment=(int*term)list L.delay
  val variables=Vector.tabulate(9,fn id=>D.delay(fn()=>Var id))
  val noArgs=D.delay(fn()=>ANil)
  val cache : ((term*term)S.stream Array.array)option ref=ref NONE
  fun variable id=if id>=0 andalso id<9 then Vector.sub(variables,id)else raise Fail "invalid variable ID"
  fun argsFrom []=noArgs | argsFrom(first::rest)=D.delay(fn()=>ACons(first,argsFrom rest))
  fun app id arguments=D.delay(fn()=>
    let val args=D.delay(fn()=>D.force(argsFrom(arguments())))
        val rules=Array.sub(valOf(!cache),id)
    in Fun(id,args,rules)end)
  structure Data=BenchBoyerDataFn(struct type term=term val variable=variable val app=app end)
  val _=cache:=SOME(Array.tabulate(50,fn id=>L.delay(fn()=>L.force(Data.rules id))))
  fun equal first second=case(D.force first,D.force second)of
      (Var a,Var b)=>a=b
    |(Fun(a,xs,_),Fun(b,ys,_))=>a=b andalso equalArgs xs ys
    |_=>false
  and equalArgs first second=case(D.force first,D.force second)of
      (ANil,ANil)=>true
    |(ACons(x,xs),ACons(y,ys))=>equal x y andalso equalArgs xs ys
    |_=>false
  fun find id environment=
    let fun loop []=(false,L.delay(fn()=>raise Fail "find"))
          | loop((key,value)::rest)=if id=key then(true,L.delay(fn()=>value))else loop rest
    in loop(L.force environment)end
  fun unify first second environment=case D.force second of
      Var id=>let val(found,value)=find id environment
              in if found then(equal first(L.force value),environment)
                 else(true,L.delay(fn()=>(id,first)::L.force environment))end
    |Fun(id,args,_) =>(case D.force first of Fun(other,values,_)=>
         if id=other then unifyArgs values args environment else(false,L.delay(fn()=>raise Fail "unify"))
       |_ =>(false,L.delay(fn()=>raise Fail "unify")))
  and unifyArgs first second environment=case(D.force first,D.force second)of
      (ANil,ANil)=>(true,environment)
    |(ACons(x,xs),ACons(y,ys))=>
      let val head=L.delay(fn()=>unify x y environment)
          val tail=L.delay(fn()=>unifyArgs xs ys(#2(L.force head)))
      in (#1(L.force head)andalso #1(L.force tail),L.delay(fn()=>L.force(#2(L.force tail))))end
    |_ =>(false,L.delay(fn()=>raise Fail "unify_lst"))
  fun subst environment term=D.delay(fn()=>case D.force term of
      Var id=>let val(found,value)=find id environment
              in if found then D.force(L.force value)else D.force term end
    |Fun(id,args,rules)=>Fun(id,mapArgs(subst environment)args,rules))
  and mapArgs f args=D.delay(fn()=>case D.force args of ANil=>ANil
    |ACons(head,tail)=>ACons(f head,mapArgs f tail))
  fun rewrite term=D.delay(fn()=>case D.force term of Var _=>D.force term
    |Fun(id,args,rules)=>D.force(rewriteRules(D.delay(fn()=>Fun(id,mapArgs rewrite args,rules)))rules))
  and rewriteRules term rules=case L.force rules of S.Nil=>term
    |S.Cons(pair,rest)=>let val(lhs,rhs)=L.force pair val(matched,environment)=unify term lhs(L.delay(fn()=>[]))
                       in if matched then rewrite(subst environment rhs)else rewriteRules term rest end
  fun member term []=false |member term(first::rest)=equal term first orelse member term rest
  fun isId id term=case D.force term of Fun(other,_,_)=>id=other|_=>false
  fun truep term assumptions=isId BenchBoyerIds.trueId term orelse member term assumptions
  fun falsep term assumptions=isId BenchBoyerIds.falseId term orelse member term assumptions
  fun ifArgs args=case D.force args of ACons(a,rest)=>(case D.force rest of ACons(b,tail)=>(case D.force tail of
      ACons(c,last)=>(case D.force last of ANil=>SOME(a,b,c)|_=>NONE)|_=>NONE)|_=>NONE)|_=>NONE
  fun tautologyp term truths falsities=
    if truep term truths then true else if falsep term falsities then false else
    case D.force term of Fun(id,args,_)=>
      if id<>BenchBoyerIds.ifId then false else(case ifArgs args of NONE=>false|SOME(condition,yes,no)=>
        if truep condition truths then tautologyp yes truths falsities
        else if falsep condition falsities then tautologyp no truths falsities
        else tautologyp yes(condition::truths)falsities andalso tautologyp no truths(condition::falsities))
    |_=>false
  fun input id=subst(L.delay(fn()=>Data.bindings()))(Data.theorem(variable id))
  fun normal id=rewrite(input id)
  fun test id=tautologyp(normal id)[][]
  fun write term emit=case D.force term of Var id=>emit("?"^Vector.sub(BenchBoyerIds.names,id))
    |Fun(id,args,_)=>
      let fun rest args=case D.force args of ANil=>()|ACons(head,tail)=>(emit " ";write head emit;rest tail)
      in emit("("^Vector.sub(BenchBoyerIds.names,id));rest args;emit ")"end
end
