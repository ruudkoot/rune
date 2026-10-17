functor BenchHartelTypecheckFn(P:sig val eagerChildren:bool end)=
struct
  structure T=BenchHartelTypesFn(P)
  open T
  datatype expNode=Var of string|Lambda of string*expNode L.delay
    |Apply of expNode L.delay*expNode L.delay
    |Let of string S.stream*expNode L.delay S.stream*expNode L.delay
    |LetRec of string S.stream*expNode L.delay S.stream*expNode L.delay
  type exp=expNode L.delay
  fun variable name=L.delay(fn()=>Var name)
  fun lambda name body=L.delay(fn()=>Lambda(name,body))
  fun apply a b=L.delay(fn()=>Apply(a,b))
  fun lambdas names body=List.foldr(fn(name,rest)=>lambda name rest)body names
  fun letExp names rhs body=L.delay(fn()=>Let(S.fromList names,S.fromList rhs,body))
  fun recursive names rhs body=L.delay(fn()=>LetRec(S.fromList names,S.fromList rhs,body))
  fun tc env ns expression=case L.force expression of
      Var name=>OK(identity,instanceType ns(lookup env name))
    |Apply(a,b)=>
       let val name=nextName ns
       in case tcList env(deplete ns)(S.fromList[a,b])of Failure=>Failure
         |OK(phi,types)=>(case S.take 3 types of [a,b]=>
            (case unify phi(a,arrow b(tv name))of Failure=>Failure|OK next=>OK(next,next name))
           |_=>raise Match) end
    |Lambda(name,body)=>
       let val v=nextName ns
           val extended=S.cons(L.delay(fn()=>bound(name,v)),env)
       in case tc extended(deplete ns)body of Failure=>Failure
         |OK(phi,typ)=>OK(phi,arrow(phi v)typ)end
    |Let(names,rhs,body)=>
       let val(ns0,ns1)=split ns
       in case tcList env ns1 rhs of Failure=>Failure|OK(phi,types)=>
         let val env'=substituteEnv phi env val(schemeNs,bodyNs)=split ns0
             val extended=addDeclarations env' schemeNs names types
         in composeReply phi(tc extended bodyNs body)end end
    |LetRec(names,rhs,body)=>
       let val(ns0,other)=split ns val(ns1,ns2)=split other
           val bounds=newBounds names ns2
       in case tcList(S.append bounds env)ns1 rhs of Failure=>Failure|OK(phi,types)=>
         let val bound'=substituteEnv phi bounds
             val env'=substituteEnv phi env
             val oldTypes=S.map oldBound bound'
         in case unifyList phi(S.zipWith(fn(a,b)=>(a,b))types oldTypes)of Failure=>Failure
           |OK next=>let val bound''=substituteEnv next bound'
                         val env''=substituteEnv next env'
                         val types'=S.map oldBound bound''
                         val(schemeNs,bodyNs)=split ns0
                         val extended=addDeclarations env'' schemeNs(envNames bounds)types'
                     in composeReply next(tc extended bodyNs body)end end end
  and tcList env ns expressions=case L.force expressions of S.Nil=>OK(identity,S.empty())
    |S.Cons(expression,rest)=>
       let val(ns0,ns1)=split ns
       in case tc env ns1(L.force expression)of Failure=>Failure|OK(phi,typ)=>
         let val env'=substituteEnv phi env
         in case tcList env' ns0 rest of Failure=>Failure|OK(psi,types)=>
           OK(compose psi phi,S.cons(L.delay(fn()=>substitute psi typ),types))end end
  and composeReply phi Failure=Failure
    |composeReply phi(OK(next,typ))=OK(compose next phi,typ)
  val initialSupply=[0]
  val initialEnv=
    S.fromList[("add",scheme(S.empty())(arrow tint(arrow tint tint))),
      ("0",scheme(S.empty())tint),("1",scheme(S.empty())tint),
      ("if",scheme(S.singleton"*")(arrow tbool(arrow star(arrow star star)))),
      ("cons",scheme(S.singleton"*")(arrow star(arrow(list star)(list star)))),
      ("head",scheme(S.singleton"*")(arrow(list star)star)),
      ("tail",scheme(S.singleton"*")(arrow(list star)(list star))),
      ("null",scheme(S.singleton"*")(arrow(list star)tbool)),
      ("NIL",scheme(S.singleton"*")(list star))]
  fun check expression=case tc initialEnv initialSupply expression of Failure=>"failure"|OK(_,typ)=>printType typ
end
