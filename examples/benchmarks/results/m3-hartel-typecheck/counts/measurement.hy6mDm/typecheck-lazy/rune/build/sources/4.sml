functor BenchHartelTypesFn(P:sig val eagerChildren:bool end)=
struct
  structure L=BenchLazy
  structure S=BenchStream
  datatype tyNode=TV of string|TC of string*tyNode L.delay S.stream
  type ty=tyNode L.delay
  type subst=string->ty
  datatype 'a reply=OK of 'a|Failure
  datatype schemeNode=Scheme of string S.stream*ty
  type scheme=schemeNode L.delay
  type env=(string*scheme)S.stream
  fun tv name=L.delay(fn()=>TV name)
  fun forceChildren xs=S.fromList(rev(S.foldl(fn(t,ts)=>(L.force t;t::ts))[]xs))
  fun con name children=L.delay(fn()=>TC(name,if P.eagerChildren then forceChildren children else children))
  fun arrow a b=con "arrow"(S.fromList[a,b])
  fun cross a b=con "cross"(S.fromList[a,b])
  fun list a=con "list"(S.singleton a)
  val tint=con "int"(S.empty())
  val tbool=con "bool"(S.empty())
  val star=tv"*"
  fun scheme names t=L.delay(fn()=>Scheme(names,t))
  fun member name values=case L.force values of S.Nil=>false
    |S.Cons(x,rest)=>name=L.force x orelse member name rest
  fun equal a b=case(L.force a,L.force b)of
      (TV x,TV y)=>x=y
    |(TC(x,xs),TC(y,ys))=>x=y andalso equalList xs ys
    |_=>false
  and equalList xs ys=case(L.force xs,L.force ys)of(S.Nil,S.Nil)=>true
    |(S.Cons(x,xr),S.Cons(y,yr))=>equal(L.force x)(L.force y)andalso equalList xr yr
    |_=>false
  fun variables typ=L.delay(fn()=>case L.force typ of TV x=>L.force(S.singleton x)
    |TC(_,children)=>L.force(S.concatMap variables children))
  fun printType typ=case L.force typ of TV name=>"<"^name^">"
    |TC(name,children)=>
      let val args=S.take 3 children
      in case(name,args)of("arrow",[a,b])=>"("^printType a^" -> "^printType b^")"
        |("list",[a])=>"["^printType a^"]"
        |("cross",[a,b])=>"("^printType a^" x "^printType b^")"
        |(_,[])=>name
        |_=>"("^name^String.concat(rev(S.foldl(fn(t,ss)=>(" "^printType t)::ss)[]children))^")"end
  fun substitute phi typ=L.delay(fn()=>case L.force typ of TV name=>L.force(phi name)
    |TC(name,children)=>L.force(con name(S.map(substitute phi)children)))
  fun compose second first name=substitute second(first name)
  val identity=tv
  fun delta name typ other=if name=other then typ else tv other
  fun extend phi name typ=if equal typ(tv name)then OK phi
    else if member name(variables typ)then Failure else OK(compose(delta name typ)phi)
  fun unify phi(a,b)=case L.force a of TV name=>
        let val known=phi name val right=substitute phi b
        in if equal known(tv name)then extend phi name right else unify phi(known,right)end
    |TC(name,children)=>(case L.force b of TV variable=>unify phi(tv variable,a)
       |TC(other,args)=>if name=other then unifyList phi(S.zipWith(fn(x,y)=>(x,y))children args)else Failure)
  and unifyList phi pairs=
    let fun fold xs=case L.force xs of S.Nil=>OK phi
          |S.Cons(pair,rest)=>case fold rest of Failure=>Failure|OK next=>unify next(L.force pair)
    in fold pairs end
  fun exclude phi names name=if member name names then tv name else phi name
  fun schemeUnknowns value=L.delay(fn()=>case L.force value of Scheme(names,typ)=>
    L.force(S.filter(fn x=>not(member x names))(variables typ)))
  fun substituteScheme phi value=L.delay(fn()=>case L.force value of Scheme(names,typ)=>
    Scheme(names,substitute(exclude phi names)typ))
  fun envNames(env:env)=S.map #1 env
  fun lookup(env:env)name=case L.force env of S.Nil=>raise Empty
    |S.Cons(entry,rest)=>let val(key,value)=L.force entry in if key=name then value else lookup rest name end
  fun envRange env=S.map(lookup env)(envNames env)
  fun envUnknowns env=S.concatMap schemeUnknowns(envRange env)
  fun substituteEnv phi env=S.map(fn(name,value)=>(name,substituteScheme phi value))env
  fun nextName ns=
    let fun dot n="."^Int.toString n
        val text=String.concat(List.map dot ns)
    in String.extract(text,1,NONE)end
  fun deplete(n::ns)=(n+2)::ns|deplete _=raise Empty
  fun split ns=(0::ns,1::ns)
  fun nameSequence ns=S.cons(L.delay(fn()=>nextName ns),L.delay(fn()=>L.force(nameSequence(deplete ns))))
  fun assoc values name=case L.force values of S.Nil=>raise Empty
    |S.Cons(entry,rest)=>let val(key,value)=L.force entry in if key=name then value else assoc rest name end
  fun assocDomain(values:(string*string)S.stream)=S.map #1 values
  fun assocSubstitution values name=if member name(assocDomain values)then tv(assoc values name)else tv name
  fun instanceType ns value=case L.force value of Scheme(names,typ)=>
    substitute(assocSubstitution(S.zipWith(fn(x,y)=>(x,y))names(nameSequence ns)))typ
  fun remove values excluded=S.filter(fn x=>not(member x excluded))values
  fun noDuplicates values=
    let fun loop acc xs=case L.force xs of S.Nil=>acc
          |S.Cons(x,rest)=>if member(L.force x)acc then loop acc rest else loop(S.cons(x,acc))rest
    in loop(S.empty())values end
  fun generalize unknowns ns typ=
    let val names=remove(noDuplicates(variables typ))unknowns
        val pairs=S.zipWith(fn(x,y)=>(x,y))names(nameSequence ns)
    in scheme(S.map #2 pairs)(substitute(assocSubstitution pairs)typ)end
  fun addDeclarations env ns names types=
    let val unknowns=envUnknowns env
        val schemes=S.map(generalize unknowns ns)types
    in S.append(S.zipWith(fn(x,y)=>(x,y))names schemes)env end
  fun bound(name,variable)=(name,scheme(S.empty())(tv variable))
  fun newBounds names ns=S.map bound(S.zipWith(fn(x,y)=>(x,y))names(nameSequence ns))
  fun oldBound(_,value)=case L.force value of Scheme(names,typ)=>
    (case L.force names of S.Nil=>typ|_=>raise Match)
end
