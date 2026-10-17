functor BenchEventFiniteFn(D:BENCH_SUSPEND)=
struct
  datatype 'a node=Nil|Cons of 'a D.t*'a node D.t
  type 'a seq='a node D.t
  fun empty()=D.delay(fn()=>Nil)
  fun cons(x,xs)=D.delay(fn()=>Cons(x,xs))
  fun fromList []=empty()|fromList(x::xs)=D.delay(fn()=>Cons(D.delay(fn()=>x),fromList xs))
  fun defer f=D.delay(fn()=>D.force(f()))
  fun append xs ys=D.delay(fn()=>case D.force xs of Nil=>D.force ys
    |Cons(x,rest)=>Cons(x,append rest ys))
  fun take 0 xs=empty()
    |take n xs=D.delay(fn()=>case D.force xs of Nil=>Nil|Cons(x,rest)=>Cons(x,take(n-1)rest))
  fun drop 0 xs=xs
    |drop n xs=D.delay(fn()=>case D.force xs of Nil=>Nil|Cons(_,rest)=>D.force(drop(n-1)rest))
  fun nth xs index=case D.force xs of Nil=>raise Subscript
    |Cons(x,rest)=>if index=0 then D.force x else nth rest(index-1)
  fun update xs index value=append(take index xs)(cons(value,drop(index+1)xs))
  fun unify xs value=D.delay(fn()=>case D.force xs of Nil=>Cons(D.delay(fn()=>value),empty())
    |Cons(x,rest)=>if D.force x=value then Cons(x,rest)else Cons(x,unify rest value))
  fun foldl f initial xs=
    let fun loop acc values=case D.force values of Nil=>acc
          |Cons(x,rest)=>loop(defer(fn()=>f acc(D.force x)))rest
    in loop initial xs end
  fun toList xs=case D.force xs of Nil=>[]|Cons(x,rest)=>D.force x::toList rest
end
