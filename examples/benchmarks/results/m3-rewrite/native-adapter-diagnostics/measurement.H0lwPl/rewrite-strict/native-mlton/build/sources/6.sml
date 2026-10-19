functor BenchRewriteFn(P:sig val eagerChildren:bool end)=
struct
  structure E=BenchRewriteExprFn(P)
  structure Parser=BenchRewriteParserFn(E)
  open E
  fun all p xs=case L.force xs of S.Nil=>true
    |S.Cons(x,rest)=>p(L.force x)andalso all p rest
  fun any p xs=case L.force xs of S.Nil=>false
    |S.Cons(x,rest)=>p(L.force x)orelse any p rest
  datatype answer=Equal|Greater|Less|Unrelated
  fun ge a=a=Equal orelse a=Greater
  fun lexico ord xs ys=case(L.force xs,L.force ys)of(S.Nil,S.Nil)=>Equal
    |(S.Nil,_)=>Less|(_,S.Nil)=>Greater
    |(S.Cons(x,xr),S.Cons(y,yr))=>case ord(L.force x,L.force y)of
       Equal=>lexico ord xr yr|other=>other
  fun rank "E"=1|rank "*"=2|rank "I"=3|rank _=raise Match
  fun order(a,b)=case(L.force a,L.force b)of
      (Var x,Var y)=>if x=y then Equal else Unrelated
    |(Var x,Func _)=>if occurs x b then Less else Unrelated
    |(Func _,Var x)=>if occurs x a then Greater else Unrelated
    |(Func(f,xs),Func(g,ys))=>
      let fun below t values=all(fn x=>order(x,t)=Less)values
          fun above t values=any(fn x=>ge(order(x,t)))values
          fun extension()=
            let val estimate=lexico order xs ys
                val confirmed=case estimate of Equal=>true|Greater=>below a ys
                  |Less=>below b xs|Unrelated=>false
            in if confirmed then estimate else if above b xs then Greater
              else if above a ys then Less else Unrelated end
      in if rank f=rank g then extension()
         else if rank f>rank g then
           if below a ys then Greater else if above a ys then Less else Unrelated
         else if below b xs then Less else if above b xs then Greater else Unrelated end
  datatype token=Afunc of string|Avar
  datatype netNode=Switch of (string*net)S.stream*net|Return of equation S.stream
  withtype net=netNode L.delay
  fun emptyNet()=L.delay(fn()=>Return(S.empty()))
  fun lookup key xs=case L.force xs of S.Nil=>NONE
    |S.Cons(x,rest)=>let val(k,v)=L.force x in if k=key then SOME v else lookup key rest end
  fun update key f default xs=L.delay(fn()=>case L.force xs of
      S.Nil=>S.Cons(L.delay(fn()=>(key,f default)),S.empty())
    |S.Cons(x,rest)=>let val(k,v)=L.force x
      in if k=key then S.Cons(L.delay(fn()=>(key,f v)),rest)
      else S.Cons(x,update key f default rest)end)
  fun preorder values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
    |S.Cons(e,rest)=>case L.force(L.force e)of
      Var _=>S.Cons(L.delay(fn()=>Avar),preorder rest)
     |Func(f,args)=>S.Cons(L.delay(fn()=>Afunc f),preorder(S.append args rest)))
  fun thread tokens equation net=L.delay(fn()=>case(L.force tokens,L.force net)of
      (S.Nil,Return eqns)=>Return(S.cons(L.delay(fn()=>equation),eqns))
    |(S.Cons(t,ts),Switch(entries,default))=>(case L.force t of
        Afunc f=>Switch(update f(thread ts equation)(emptyNet())entries,default)
       |Avar=>Switch(entries,thread ts equation default))
    |(S.Cons(t,ts),Return eqns)=>(case L.force t of
        Afunc _=>L.force(thread tokens equation(L.delay(fn()=>Switch(S.empty(),net))))
       |Avar=>let val changed=thread ts equation net
         in case L.force changed of Switch _=>Switch(S.empty(),changed)|other=>other end)
    |_=>raise Match)
  fun addEquation net equation=thread(preorder(S.singleton(lhs equation)))equation net
  fun findStack stack net=L.delay(fn()=>case L.force net of Return eqns=>L.force eqns
    |Switch(entries,default)=>case L.force stack of S.Nil=>raise Match
      |S.Cons(e,rest)=>
        let val specific=case L.force(L.force e)of Var _=>S.empty()
              |Func(f,args)=>case lookup f entries of NONE=>S.empty()
                |SOME branch=>findStack(S.append args rest)branch
        in L.force(S.append specific(findStack rest default))end)
  fun find expression net=findStack(S.singleton expression)net
  fun mapNet f net=L.delay(fn()=>case L.force net of Return equations=>Return(f equations)
    |Switch(entries,default)=>Switch(S.map(fn(k,v)=>(k,mapNet f v))entries,mapNet f default))
  fun deleteEquations numbers=mapNet(S.filter(fn e=>not(List.exists(fn n=>n=number e)numbers)))
  fun netReduce net expression=tryAll(S.map rewrite(find expression net))expression
  fun superReduce net=inside(netReduce net)
  fun mapMaybe f values=S.concatMap(fn v=>case f v of NONE=>S.empty()|SOME x=>S.singleton x)values
  fun superpose term target=mapMaybe(fn(path,other)=>case unify term other of NONE=>NONE
    |SOME substitution=>SOME(path,substitution))(subterms target)
  fun strictSuper term target=case L.force target of Var _=>raise Match
    |Func(_,args)=>
      let fun walk i values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
            |S.Cons(x,rest)=>L.force(S.append
              (S.map(fn(path,s)=>(i::path,s))(superpose term(L.force x)))(walk(i+1)rest)))
      in walk 0 args end
  fun makeCritical e1 e2(path,s)=(sub(replace(lhs e2)path(rhs e1))s,sub(rhs e2)s)
  fun criticalPairs e1 e2=S.append(S.map(makeCritical e1 e2)(superpose(lhs e1)(lhs e2)))
    (S.map(makeCritical e2 e1)(strictSuper(lhs e2)(lhs e1)))
  fun allCritical equation theory=
    let val first=standardEquation "1" equation
        val second=standardEquation "2" equation
        val others=S.map(standardEquation "2")theory
    in S.append(S.map(makeCritical first second)(strictSuper(lhs first)(lhs second)))
      (S.concatMap(criticalPairs first)others)end
  datatype item=Item of int L.delay*(expr*expr)
  fun itemCost(Item(c,_))=L.force c
  fun insert item agenda=L.delay(fn()=>case L.force agenda of S.Nil=>S.Cons(L.delay(fn()=>item),S.empty())
    |S.Cons(x,rest)=>if itemCost item<=itemCost(L.force x)
      then S.Cons(L.delay(fn()=>item),agenda)else S.Cons(x,insert item rest))
  fun addAgenda cfun pairs agenda=L.force(S.foldrStream
    (fn(pair,rest)=>L.delay(fn()=>insert(Item(L.delay(fn()=>cfun pair),pair))(L.force rest)))
    (L.delay(fn()=>agenda))pairs)
  fun preprocess net(a,b)=(simplify(superReduce net)a,simplify(superReduce net)b)
  fun resolve net pair=let val(a,b)=preprocess net pair
    in if equal a b then NONE else SOME(a,b)end
  fun split p values=
    let val tagged=S.map(fn e=>(p e,e))values
    in (S.map #2(S.filter #1 tagged),S.map #2(S.filter(fn(b,_)=>not b)tagged))end
  fun process n theory net agenda=L.delay(fn()=>case L.force agenda of S.Nil=>L.force net
    |S.Cons(entry,todo)=>let val Item(_,pair)=L.force entry val(a,b)=preprocess net pair
      in case order(a,b)of
        Equal=>L.force(process n theory net todo)
       |Unrelated=>L.force(process n theory net(addAgenda(fn _=>1000)(S.singleton(a,b))todo))
       |answer=>
        let val newRule=if answer=Greater then Eqn(n,(a,b))else Eqn(n,(b,a))
            fun reducible e=Option.isSome(reduceOne newRule(lhs e))orelse Option.isSome(reduceOne newRule(rhs e))
            val(deleted,retained)=split reducible theory
            val numbers=rev(S.foldl(fn(e,ns)=>number e::ns)[]deleted)
            val nextNet=addEquation(deleteEquations numbers net)newRule
            val candidates=S.append(S.map E.pair deleted)(allCritical newRule retained)
            val nextAgenda=addAgenda cost(mapMaybe(resolve nextNet)candidates)todo
        in L.force(process(n+1)(S.append retained(S.singleton newRule))nextNet nextAgenda)end
      end)
  val groupRules=L.delay(fn()=>S.fromList(List.map Parser.equation["(a * b) * c = a * (b * c)","E * x = x","I(x) * x = E"]))
  val completion=L.delay(fn()=>L.force(process 1(S.empty())(emptyNet())(addAgenda cost(L.force groupRules)(S.empty()))))
  fun normalize expression=simplify(superReduce completion)expression
  fun result(a,b)=equal(normalize(Parser.parse a))(Parser.parse b)
  fun take count values=L.delay(fn()=>if count<=0 then S.Nil else case L.force values of
      S.Nil=>S.Nil|S.Cons(x,rest)=>S.Cons(x,take(count-1)rest))
  fun queryStream count=
    let val pair=("I(a * b)","I(b) * I(a)")
        val repeated=S.fix(fn self=>S.Cons(L.delay(fn()=>pair),self))
    in take count repeated end
  fun calculate count observe=
    let fun loop values=case L.force values of S.Nil=>true|S.Cons(entry,rest)=>
          let val(a,b)=L.force entry
              val normalized=L.delay(fn()=>L.force(normalize(Parser.parse a)))
              val target=L.delay(fn()=>L.force(Parser.parse b))
          in if equal normalized target then
              ((case observe of NONE=>()|SOME f=>f(render normalized));loop rest)
             else false end
    in loop(queryStream count)end
  fun test n=calculate n NONE
  fun rules net=case L.force net of Return eqns=>eqns
    |Switch(entries,default)=>S.append(S.concatMap(fn(_,branch)=>rules branch)entries)(rules default)
end
