(* nofib integer functional geometry: keep every intermediate floor division. *)
functor BenchFishFn(D : BENCH_SUSPEND) =
struct
 structure Q=BenchCellSequenceFn(D)
 type vector=(int D.t*int D.t)D.t
 type segment=int D.t*int D.t*int D.t*int D.t
 type picture=vector->vector->vector->segment Q.sequence
 fun value x=D.delay(fn()=>x)
 fun vector(x,y)=value(value x,value y)
 val zero=vector(0,0)
 fun add first second=D.delay(fn()=>let val(x,y)=D.force first
                                          val(u,v)=D.force second
     in(D.delay(fn()=>D.force x+D.force u),D.delay(fn()=>D.force y+D.force v))end)
 fun sub first second=D.delay(fn()=>let val(x,y)=D.force first
                                          val(u,v)=D.force second
     in(D.delay(fn()=>D.force x-D.force u),D.delay(fn()=>D.force y-D.force v))end)
 fun scale_vec2 point a b=D.delay(fn()=>let val(x,y)=D.force point
     in(D.delay(fn()=>D.force x*a div b),D.delay(fn()=>D.force y*a div b))end)
 TABLES
 fun tup2 first second=let val(x,y)=D.force first
                          val(u,v)=D.force second in(x,y,u,v)end
 fun emptyPicture _ _ _=Q.empty()
 fun grid m n segments a b c=Q.map(fn(x0,y0,x1,y1)=>
   tup2(add(add a(scale_vec2 b x0 m))(scale_vec2 c y0 n))
       (add(add a(scale_vec2 b x1 m))(scale_vec2 c y1 n)))segments
 fun rot p a b c=p(add a b)c(sub zero b)
 fun beside m n p q a b c=D.delay(fn()=>D.force(Q.append(p a(scale_vec2 b m(m+n))c)
   (D.delay(fn()=>D.force(q(add a(scale_vec2 b m(m+n)))(scale_vec2 b n(n+m))c)))))
 fun above m n p q a b c=D.delay(fn()=>D.force(Q.append(p(add a(scale_vec2 c n(m+n)))b(scale_vec2 c m(n+m)))
   (D.delay(fn()=>D.force(q a b(scale_vec2 c n(m+n)))))))
 val p=grid 16 16 p_tile
 val q=grid 16 16 q_tile
 val r=grid 16 16 r_tile
 val s=grid 16 16 s_tile
 fun quartet a b c d=above 1 1(beside 1 1 a b)(beside 1 1 c d)
 val t=quartet p q r s
 fun cycle p1=quartet p1(rot(rot(rot p1)))(rot p1)(rot(rot p1))
 val u=cycle(rot q)
 val side1=quartet emptyPicture emptyPicture(rot t)t
 val side2=quartet side1 side1(rot t)t
 val corner1=quartet emptyPicture emptyPicture emptyPicture u
 val corner2=quartet corner1 side1(rot side1)u
 val pseudocorner=quartet corner2 side2(rot side2)(rot t)
 val pseudolimit=cycle pseudocorner
 fun chars text=Q.fromList(String.explode text)
 fun positive n=D.delay(fn()=>if n<10 then Q.Cons(D.delay(fn()=>Char.chr(48+n)),Q.empty())
   else D.force(Q.append(positive(n div 10))(Q.cons(D.delay(fn()=>Char.chr(48+n mod 10)))(Q.empty()))))
 fun number field=D.delay(fn()=>let val n=D.force field
   in if n<0 then Q.Cons(Q.value #"-",positive(~n))else D.force(positive n)end)
 fun segmentText segment=D.delay(fn()=>let val(a,b,c,d)=D.force segment
   in D.force(Q.append(chars "(")(Q.append(number a)(Q.append(chars ",")
     (Q.append(number b)(Q.append(chars ",")(Q.append(number c)(Q.append(chars ",")
       (Q.append(number d)(chars ")")))))))))end)
 fun showl segments finish=D.delay(fn()=>case D.force segments of Q.Nil=>D.force(Q.cons(Q.value #"]")finish)
   | Q.Cons(x,rest)=>D.force(Q.append(chars ",\n")(Q.append(segmentText x)(showl rest finish))))
 fun fmt segments=D.delay(fn()=>case D.force segments of Q.Nil=>D.force(chars "[]")
   | Q.Cons(x,rest)=>D.force(Q.append(chars "[\n")(Q.append(segmentText x)(showl rest(Q.empty())))))
 fun length xs=let fun loop xs n=case D.force xs of Q.Nil=>n | Q.Cons(_,rest)=>loop rest(n+1)in loop xs 0 end
 fun tuples segments=List.map(fn(a,b,c,d)=>(D.force a,D.force b,D.force c,D.force d))(Q.toList segments)
end
