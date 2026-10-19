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
 val p_tile=Q.fromList[(0,3,3,4),(3,4,0,8),(0,8,0,3),(6,0,4,4),(4,5,4,10),(4,10,7,6),(7,6,4,5),(11,0,10,4),(10,4,9,6),(9,6,8,8),(8,8,4,13),(4,13,0,16),(0,16,6,15),(6,15,8,16),(8,16,12,12),(12,12,16,12),(10,16,12,14),(12,14,16,13),(12,16,13,15),(13,15,16,14),(14,16,16,15),(8,12,16,10),(8,8,12,9),(12,9,16,8),(9,6,12,7),(12,7,16,6),(10,4,13,5),(13,5,16,4),(11,0,14,2),(14,2,16,2)]
 val q_tile=Q.fromList[(0,8,4,7),(4,7,6,7),(6,7,8,8),(8,8,12,10),(12,10,16,16),(0,12,3,13),(3,13,5,14),(5,14,7,15),(7,15,8,16),(2,16,3,13),(4,16,5,14),(6,16,7,15),(0,10,7,11),(9,13,8,15),(8,15,11,15),(11,15,9,13),(10,10,8,12),(8,12,12,12),(12,12,10,10),(2,0,4,5),(4,5,4,7),(4,0,6,5),(6,5,6,7),(6,0,8,5),(8,5,8,8),(10,0,14,11),(12,0,13,4),(13,4,16,8),(16,8,15,10),(15,10,16,16),(13,0,16,6),(14,0,16,4),(15,0,16,2),(0,0,8,0),(12,0,16,0),(0,0,0,8),(0,12,0,16)]
 val r_tile=Q.fromList[(0,0,8,8),(12,12,16,16),(0,4,5,10),(0,8,2,12),(0,12,1,14),(16,6,11,10),(11,10,6,16),(16,4,14,6),(14,6,8,8),(8,8,5,10),(5,10,2,12),(2,12,0,16),(16,8,12,12),(12,12,11,16),(1,1,4,0),(2,2,8,0),(3,3,8,2),(8,2,12,0),(5,5,12,3),(12,3,16,0),(11,16,12,12),(12,12,16,8),(13,13,16,10),(14,14,16,12),(15,15,16,14)]
 val s_tile=Q.fromList[(0,0,4,2),(4,2,8,2),(8,2,16,0),(0,4,2,1),(0,6,7,4),(0,8,8,6),(0,10,7,8),(0,12,7,10),(0,14,7,13),(13,13,16,14),(14,11,16,12),(15,9,16,10),(16,0,10,4),(10,4,8,6),(8,6,7,8),(7,8,7,13),(7,13,8,16),(12,16,13,13),(13,13,14,11),(14,11,15,9),(15,9,16,8),(10,16,11,10),(12,4,10,6),(10,6,12,7),(12,7,12,4),(15,5,13,7),(13,7,15,8),(15,8,15,5)]
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
