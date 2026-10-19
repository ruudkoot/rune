functor BenchReptileFn(D:BENCH_SUSPEND)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure W=Word64
 structure S=BenchSigned64
 type integer=W.word D.t
 type text=char F.seq
 type integers=W.word F.seq
 type segments=W.word F.node F.seq
 type drawing=(integers*integers)F.seq
 type association=((integer*integer)D.t*integer)F.seq
 type state=(drawing*integer*association)L.delay
 fun int n=D.delay(fn()=>W.fromInt n)
 fun text s=F.fromList(String.explode s)
 fun string s=String.implode(F.toList s)
 fun number value=
   let val word=D.force value val magnitude=W.toLargeInt word
       val signed=if S.negative word then magnitude-18446744073709551616 else magnitude
   in String.map(fn #"~"=> #"-"|c=>c)(IntInf.toString signed)end
 fun showInt value=F.defer(fn()=>text(number value))
 fun add a b=D.delay(fn()=>W.+(D.force a,D.force b))
 fun sub a b=D.delay(fn()=>W.-(D.force a,D.force b))
 fun mul a b=D.delay(fn()=>W.*(D.force a,D.force b))
 fun divide a b=D.delay(fn()=>S.divide(D.force a,D.force b))
 fun modulo a b=D.delay(fn()=>S.modulo(D.force a,D.force b))
 fun negative a=D.delay(fn()=>S.negate(D.force a))
 fun absolute a=D.delay(fn()=>S.magnitude(D.force a))
 fun eq a b=D.force a=D.force b
 fun lt a b=S.less(D.force a,D.force b)
 fun le a b=S.leq(D.force a,D.force b)
 fun gt a b=lt b a
 fun ge a b=le b a
 fun singleton value=F.cons(value,F.empty())
 fun pair a b=D.delay(fn()=>(a,b))
 fun ints values=List.foldr(fn(n,rest)=>F.cons(int n,rest))(F.empty())values
 fun map f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
   |F.Cons(value,rest)=>F.cons(D.delay(fn()=>D.force(f value)),map f rest))
 fun flatMap f values=F.defer(fn()=>case D.force values of F.Nil=>F.empty()
   |F.Cons(value,rest)=>F.append(f value)(flatMap f rest))
 fun foldr f initial values=D.delay(fn()=>case D.force values of F.Nil=>D.force initial
   |F.Cons(value,rest)=>D.force(f value(foldr f initial rest)))
 fun head values=case D.force values of F.Cons(value,_)=>value|F.Nil=>raise Fail"Prelude.head: empty list"
 fun tail values=F.defer(fn()=>case D.force values of F.Cons(_,rest)=>rest|F.Nil=>raise Fail"Prelude.tail: empty list")
 fun null values=case D.force values of F.Nil=>true|_=>false
 fun length values=D.delay(fn()=>
   let fun loop n values=case D.force values of F.Nil=>n|F.Cons(_,rest)=>loop(n+1)rest
   in W.fromInt(loop 0 values)end)
 fun reverse values=F.defer(fn()=>
   let fun loop values result=case D.force values of F.Nil=>result|F.Cons(value,rest)=>loop rest(F.cons(value,result))
   in loop values(F.empty())end)
 fun list4 values=
   let val a=head values val values=tail values val b=head values
       val values=tail values val c=head values val values=tail values val d=head values
   in if null(tail values)then(a,b,c,d)else raise Match end
 fun list2 values=
   let val a=head values val rest=tail values val b=head rest
   in if null(tail rest)then(a,b)else raise Match end
