(* Brian D. Moe's dense block operations, converted to Haskell by
   Ian R. McLelland and Cordelia V. Hall; original notices retained. *)
functor BenchLinearDenseFn(D:BENCH_SUSPEND) =
struct
  structure L=BenchLazy
  structure S=BenchStream
  structure F=BenchLinearFloat
  type number=real D.t
  type vector=number S.stream
  type matrix=vector S.stream
  fun value(x:number)=D.force x
  fun number(x:real)=D.delay(fn()=>F.round x)
  fun scalar f=D.delay(fn()=>F.round(f()))
  fun add(a:number,b:number)=scalar(fn()=>value a+value b)
  fun sub(a:number,b:number)=scalar(fn()=>value a-value b)
  fun mul(a:number,b:number)=scalar(fn()=>value a*value b)
  fun divide(a:number,b:number)=scalar(fn()=>value a/value b)
  fun negate a=scalar(fn()=> ~(value a))
  fun sqrt a=scalar(fn()=>let val x=value a in if x<0.0 then 0.0/0.0 else Math.sqrt x end)
  val zero=number 0.0 val one=number 1.0
  fun empty xs=case L.force xs of S.Nil=>true|_=>false
  fun length xs=
    let fun loop n xs=case L.force xs of S.Nil=>n|S.Cons(_,rest)=>loop(n+1)rest
    in loop 0 xs end
  fun delay f=L.delay(fn()=>L.force(f()))
  fun range first last=L.delay(fn()=>if first>last then S.Nil else
    S.Cons(L.delay(fn()=>first),range(first+1)last))
  fun take n xs=L.delay(fn()=>if n<=0 then S.Nil else case L.force xs of S.Nil=>S.Nil
    |S.Cons(x,rest)=>S.Cons(x,take(n-1)rest))
  fun drop n xs=L.delay(fn()=>if n<=0 then L.force xs else case L.force xs of S.Nil=>S.Nil
    |S.Cons(_,rest)=>L.force(drop(n-1)rest))
  fun repeat n x=L.delay(fn()=>if n<=0 then S.Nil else S.Cons(L.delay(fn()=>x),repeat(n-1)x))
  fun concat xs=S.concatMap(fn x=>x)xs
  fun fold1 f xs=case L.force xs of S.Nil=>raise Empty
    |S.Cons(first,rest)=>S.foldl(fn(x,total)=>f(total,x))(L.force first)rest
  fun vec values=S.fromList(List.map number values)
  fun block rows=S.fromList(List.map vec rows)
  fun vadd a b=S.zipWith add a b
  fun vsub a b=S.zipWith sub a b
  fun vneg a=S.map negate a
  fun smul s v=S.map(fn x=>mul(x,s))v
  fun dot a b=scalar(fn()=>value(S.foldl(fn(x,total)=>add(total,x))zero(S.zipWith mul a b)))
  fun norm v=dot v v
  fun madd a b=S.zipWith(fn(x,y)=>vadd x y)a b
  fun msub a b=S.zipWith(fn(x,y)=>vsub x y)a b
  fun outer u v=S.map(fn k=>S.map(fn x=>mul(k,x))u)v
  fun rows m=length m
  fun columns m=length(S.head m)
  fun getRow i m=S.nth m i
  fun getCol i m=S.map(fn row=>S.nth row i)m
  fun subscript m(i,j)=S.nth(S.nth m i)j
  fun mmult m n=delay(fn()=>
    if columns m<>rows n then raise Fail "incompatible dense matrices"else
      S.map(fn i=>S.map(fn j=>dot(S.nth m i)(getCol j n))(range 0(columns n-1)))(range 0(rows m-1)))
  fun matvec m v=S.map(fn row=>dot v row)m
  fun vecmat v m=concat(mmult(S.singleton v)m)
  fun identity n=S.map(fn i=>S.append(repeat(i-1)zero)
      (S.cons(L.delay(fn()=>one),repeat(n-i)zero)))(range 1 n)
  fun swap a b xs=delay(fn()=>if a<b then
        S.append(take a xs)(S.cons(L.delay(fn()=>S.nth xs b),
          S.append(take(b-a-1)(drop(a+1)xs))(S.cons(L.delay(fn()=>S.nth xs a),drop(b+1)xs))))
      else if a>b then swap b a xs else xs)
  fun swapRows a b m=swap a b m
  fun swapCols a b m=S.map(fn row=>swap a b row)m
  fun absNumber x=if value x<0.0 then negate x else x
  fun findPivot m=
    let val diagonal=S.map(fn i=>subscript m(i,i))(range 0(rows m-1))
        val maximum=fold1(fn(a,b)=>if value a<=value b then b else a)(S.map absNumber diagonal)
        fun locate i values=case L.force values of S.Nil=>raise Empty
          |S.Cons(x,rest)=>if Real.==(value(absNumber(L.force x)),value maximum)then i
             else locate(i+1)rest
    in locate 0 diagonal end
  datatype factor=LU of vector S.stream*vector S.stream*int S.stream
  fun factorLower(LU(l,_,_))=l
  fun factorUpper(LU(_,u,_))=u
  fun factorPermutation(LU(_,_,p))=p
  fun lu a=L.delay(fn()=>
    if rows a=1 then LU(S.empty(),S.singleton(S.singleton(subscript a(0,0))),S.singleton 1)
    else
      let val pivot=L.delay(fn()=>let val p=findPivot a
            in(swapRows 0 p(swapCols 0 p a),p)end)
          val u=delay(fn()=>getRow 0(#1(L.force pivot)))
          val m=delay(fn()=>getCol 0(#1(L.force pivot)))
          val u11=scalar(fn()=>value(S.head u))
          val lower=delay(fn()=>if not(Real.==(value u11,0.0))
            then S.tail(S.map(fn x=>divide(x,u11))m)else raise Fail "zero pivot in block LU")
          val a11=delay(fn()=>S.map S.tail(S.tail(#1(L.force pivot))))
          val reduced=msub a11(outer(S.tail u)lower)
          val remaining=L.delay(fn()=>L.force(lu reduced))
      in LU(S.cons(L.delay(fn()=>lower),delay(fn()=>factorLower(L.force remaining))),
            S.cons(L.delay(fn()=>u),delay(fn()=>factorUpper(L.force remaining))),
            S.cons(L.delay(fn()=> #2(L.force pivot)),delay(fn()=>factorPermutation(L.force remaining))))end)
  fun forward lower permutations b=delay(fn()=>case L.force lower of S.Nil=>b
    |S.Cons(l,ls)=>
      let val swapped=swapRows 0(S.head permutations)b
          val first=delay(fn()=>S.head swapped)
          val rest=delay(fn()=>S.tail swapped)
          val reduced=msub rest(outer first(L.force l))
      in S.cons(L.delay(fn()=>first),forward ls(S.tail permutations)reduced)end)
  fun backward upper permutations y=delay(fn()=>
    if length upper=1 andalso length(S.head upper)=1 then
      let val u=S.head(S.head upper)in S.map(fn row=>S.map(fn x=>divide(x,u))row)y end
    else
      let val row=delay(fn()=>S.head upper)
          val u1=scalar(fn()=>value(S.head row))
          val rest=backward(S.tail upper)(S.tail permutations)(S.tail y)
          val current=S.map(fn x=>divide(x,u1))(vsub(S.head y)(vecmat(S.tail row)rest))
      in swapRows 0(S.head permutations)(S.cons(L.delay(fn()=>current),rest))end)
  fun inverse m=delay(fn()=>
    let val f=L.force(lu m)
    in backward(factorUpper f)(factorPermutation f)
      (forward(factorLower f)(factorPermutation f)(identity(rows m)))end)
end
