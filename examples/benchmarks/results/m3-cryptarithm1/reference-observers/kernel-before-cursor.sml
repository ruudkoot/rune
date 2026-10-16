(* Mechveliani's exhaustive nofib cryptarithm1: insertion permutation order. *)
functor BenchCryptarithmPermutationFn(D : BENCH_SUSPEND) =
struct
  structure S=BenchCellSequenceFn(D)
  fun concatMap f xs=D.delay(fn()=>case D.force xs of S.Nil=>S.Nil
    | S.Cons(x,rest)=>D.force(S.append(f(D.force x))(concatMap f rest)))
  fun addj j xs=D.delay(fn()=>case D.force xs of
      S.Nil=>S.Cons(S.value(S.cons j(S.empty())),S.empty())
    | S.Cons(k,ks)=>S.Cons(S.value(S.cons j(S.cons k ks)),
        S.map(fn aks=>S.cons k aks)(addj j ks)))
  fun permutations xs=D.delay(fn()=>case D.force xs of
      S.Nil=>S.Cons(S.value(S.empty()),S.empty())
    | S.Cons(j,js)=>D.force(concatMap(addj j)(permutations js)))
  fun filter predicate xs=D.delay(fn()=>
    let fun seek remaining=case D.force remaining of S.Nil=>S.Nil
          | S.Cons(x,rest)=>if predicate(D.force x)then S.Cons(x,filter predicate rest)
                            else seek rest
    in seek xs end)
  fun expand(a,b,c,d,e,f)=f+e*10+d*100+c*1000+b*10000+a*100000
  fun condition row=case S.toList row of [t,h,i,r,y,w,e,l,v,n]=>
        expand(t,h,i,r,t,y)+5*expand(t,w,e,l,v,e)=expand(n,i,n,e,t,y)
    | _=>raise Fail "cryptarithm1 requires ten digits"
  fun range lo hi=D.delay(fn()=>if lo>hi then S.Nil
    else S.Cons(S.value lo,range(lo+1)hi))
  fun selected i=filter condition(permutations(S.take 10(range 0(9+i))))
  fun renderRows rows=
    "["^String.concatWith ","(List.map(fn row=>
       "["^String.concatWith ","(List.map Int.toString(S.toList row))^"]")
       (S.toList rows))^"]\n"
  fun run i=renderRows(selected i)
end
