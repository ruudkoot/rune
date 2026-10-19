functor BenchRewriteExprFn(P:sig val eagerChildren:bool end)=
struct
  structure L=BenchLazy
  structure S=BenchStream
  datatype exprNode=Func of string*exprNode L.delay S.stream|Var of string
  type expr=exprNode L.delay
  datatype equation=Eqn of int*(expr*expr)
  fun variable name=L.delay(fn()=>Var name)
  fun forceChildren values=S.fromList(rev(S.foldl(fn(e,es)=>(L.force e;e::es))[]values))
  fun func name children=L.delay(fn()=>Func(name,if P.eagerChildren then forceChildren children else children))
  fun equal a b=case(L.force a,L.force b)of(Var x,Var y)=>x=y
    |(Func(f,xs),Func(g,ys))=>f=g andalso equalList xs ys|_=>false
  and equalList xs ys=case(L.force xs,L.force ys)of(S.Nil,S.Nil)=>true
    |(S.Cons(x,xr),S.Cons(y,yr))=>equal(L.force x)(L.force y)andalso equalList xr yr|_=>false
  fun fold ff vv expression=
    let fun walk e=L.delay(fn()=>case L.force e of Var name=>L.force(vv name)
          |Func(name,children)=>L.force(ff name(S.map walk children)))
    in walk expression end
  fun occurs name expression=
    let fun any values=case L.force values of S.Nil=>false|S.Cons(x,rest)=>L.force(L.force x)orelse any rest
    in L.force(fold(fn _=>fn values=>L.delay(fn()=>any values))(fn v=>L.delay(fn()=>v=name))expression)end
  fun lhs(Eqn(_, (a,_)))=a
  fun rhs(Eqn(_, (_,b)))=b
  fun number(Eqn(n,_))=n
  fun pair(Eqn(_,p))=p
  fun cost(a,b)=
    let fun size e=L.force(fold(fn _=>fn values=>L.delay(fn()=>
          1+S.foldl(fn(v,n)=>L.force v+n)0 values))(fn _=>L.delay(fn()=>0))e)
    in size a+size b end
  fun assoc values name=case L.force values of S.Nil=>NONE
    |S.Cons(entry,rest)=>let val(key,value)=L.force entry
      in if key=name then SOME value else assoc rest name end
  fun apply substitution name=case assoc substitution name of NONE=>variable name|SOME value=>value
  fun sub expression substitution=fold func(apply substitution)expression
  fun compose first second=S.append(S.map(fn(name,e)=>(name,sub e first))second)first
  fun standard suffix expression=fold func(fn name=>variable(name^suffix))expression
  fun standardEquation suffix(Eqn(n,(a,b)))=Eqn(n,(standard suffix a,standard suffix b))
  fun modify values index f=L.delay(fn()=>case L.force values of S.Nil=>raise Match
    |S.Cons(x,rest)=>if index=0 then S.Cons(L.delay(fn()=>f(L.force x)),rest)
      else S.Cons(x,modify rest(index-1)f))
  fun replace expression [] value=value
    |replace expression(i::path)value=L.delay(fn()=>case L.force expression of Var _=>raise Match
      |Func(name,args)=>L.force(func name(modify args i(fn e=>replace e path value))))
  fun subterms expression=L.delay(fn()=>case L.force expression of Var _=>S.Nil
    |Func(name,args)=>
       let fun indexed index values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
             |S.Cons(e,rest)=>L.force(S.append
               (S.map(fn(path,e)=>(index::path,e))(subterms(L.force e)))(indexed(index+1)rest)))
       in L.force(S.append(S.singleton([],func name args))(indexed 0 args))end)
  fun match pattern target=
    let fun one substitution(a,b)=case L.force a of Var name=>
            (case assoc substitution name of NONE=>SOME(S.cons(L.delay(fn()=>(name,b)),substitution))
             |SOME old=>if equal old b then SOME substitution else NONE)
          |Func(f,args)=>(case L.force b of Var _=>NONE|Func(g,values)=>
              if f=g then many substitution(S.zipWith(fn(x,y)=>(x,y))args values)else NONE)
        and many substitution pairs=case L.force pairs of S.Nil=>SOME substitution
          |S.Cons(p,rest)=>case one substitution(L.force p)of NONE=>NONE|SOME next=>many next rest
    in one(S.empty())(pattern,target)end
  fun unify a b=
    let fun one substitution(a,b)=case L.force a of Var name=>variableCase substitution name b
          |Func(f,args)=>(case L.force b of Var name=>variableCase substitution name a
            |Func(g,values)=>if f=g then many substitution(S.zipWith(fn(x,y)=>(x,y))args values)else NONE)
        and variableCase substitution name value=case assoc substitution name of
             SOME old=>one substitution(old,value)
           |NONE=>if equal value(variable name)then SOME substitution else
             let val changed=sub value substitution
             in if occurs name changed then NONE
               else SOME(compose(S.singleton(name,changed))substitution)end
        and many substitution pairs=case L.force pairs of S.Nil=>SOME substitution
          |S.Cons(p,rest)=>case one substitution(L.force p)of NONE=>NONE|SOME next=>many next rest
    in one(S.empty())(a,b)end
  fun rewrite equation expression=case match(lhs equation)expression of NONE=>NONE
    |SOME substitution=>SOME(sub(rhs equation)substitution)
  fun tryAll tactics expression=case L.force tactics of S.Nil=>NONE|S.Cons(tactic,rest)=>
    case L.force tactic expression of NONE=>tryAll rest expression|some=>some
  fun inside tactic expression=
    let fun first values=case L.force values of S.Nil=>NONE|S.Cons(entry,rest)=>
          let val(path,term)=L.force entry
          in case tactic term of NONE=>first rest|SOME value=>SOME(replace expression path value)end
    in first(subterms expression)end
  fun reduceOne equation=inside(rewrite equation)
  fun reduce equations=inside(tryAll(S.map rewrite equations))
  fun simplify tactic expression=case tactic expression of NONE=>expression|SOME next=>simplify tactic next
  fun render expression=case L.force expression of Var name=>name
    |Func(name,args)=>let val values=rev(S.foldl(fn(e,es)=>render e::es)[]args)
        fun comma []=""|comma[x]=x|comma(x::xs)=x^","^comma xs
      in name^"("^comma values^")"end
end
