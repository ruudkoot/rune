(* Bird/Wadler picture combinators from nofib calendar, with explicit demand. *)
functor BenchCalendarFn(D : BENCH_SUSPEND) =
struct
 structure Q=BenchCellSequenceFn(D)
 type row=char Q.sequence
 type picture=row Q.sequence
 fun length xs=let fun loop xs n=case D.force xs of Q.Nil=>n | Q.Cons(_,rest)=>loop rest(n+1)in loop xs 0 end
 fun singleton value=Q.cons(Q.value value)(Q.empty())
 fun chars text=Q.fromList(String.explode text)
 fun spaces n=if n<=0 then Q.empty()else Q.replicate n(Q.value #" ")
 fun emptyPic h w=let val row=spaces w in Q.replicate(Int.max(0,h))(Q.value row)end
 fun zipWith f xs ys=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | Q.Cons(x,rest)=>case D.force ys of Q.Nil=>Q.Nil
     | Q.Cons(y,tail)=>Q.Cons(D.delay(fn()=>f(D.force x,D.force y)),zipWith f rest tail))
 fun drop n xs=if n<=0 then xs else case D.force xs of Q.Nil=>xs | Q.Cons(_,rest)=>drop(n-1)rest
 fun group n xs=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | _=>Q.Cons(D.delay(fn()=>Q.take n xs),D.delay(fn()=>D.force(group n(drop n xs)))))
 fun above first second=Q.append first second
 fun beside first second=zipWith(fn(a,b)=>Q.append a b)first second
 fun foldr1 join pictures=D.delay(fn()=>case D.force pictures of Q.Nil=>raise Empty
   | Q.Cons(first,rest)=>case D.force rest of Q.Nil=>D.force(D.force first)
     | _=>D.force(join(D.force first)(foldr1 join rest)))
 fun stack pictures=foldr1 above pictures
 fun spread pictures=foldr1 beside pictures
 fun block n pictures=stack(Q.map spread(group n pictures))
 fun blockT n pictures=spread(Q.map stack(group n pictures))
 fun height picture=length picture
 fun width picture=length(Q.head picture)
 fun lframe h w picture=above(beside picture(emptyPic(height picture)(w-width picture)))
   (emptyPic(h-height picture)w)
 fun show n=D.delay(fn()=>
   if n<10 then Q.Cons(D.delay(fn()=>Char.chr(48+n)),Q.empty())
   else D.force(Q.append(show(n div 10))(Q.cons(D.delay(fn()=>Char.chr(48+n mod 10)))(Q.empty()))))
 fun cjustify n row=let val m=n-length row
                       val half=m div 2
                   in Q.append(spaces half)(Q.append row(spaces(m-half)))end
 fun rjustify n row=Q.append(spaces(n-length row))row
 fun leap year=if year mod 100=0 then year mod 400=0 else year mod 4=0
 fun monthLengths year=Q.fromList[31,if leap year then 29 else 28,31,30,31,30,31,31,30,31,30,31]
 val monthNames=Q.fromList(List.map chars["January","February","March","April","May","June","July","August","September","October","November","December"])
 fun jan1st year=let val last=year-1 in(year+last div 4-last div 100+last div 400)mod 7 end
 fun firstDays year=
   let fun scan accumulator xs=D.delay(fn()=>Q.Cons(accumulator,D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
       | Q.Cons(x,rest)=>D.force(scan(D.delay(fn()=>D.force accumulator+D.force x))rest))))
   in Q.take 12(Q.map(fn x=>x mod 7)(scan(Q.value(jan1st year))(monthLengths year)))end
 fun dates first days=
   let fun loop offset=D.delay(fn()=>if offset=42 then Q.Nil else Q.Cons(D.delay(fn()=>
         let val d=1-first+offset
         in singleton(if d<1 orelse days<d then spaces 3 else rjustify 3(show d))end),loop(offset+1)))
   in loop 0 end
 fun zip3 xs ys zs=D.delay(fn()=>case D.force xs of Q.Nil=>Q.Nil
   | Q.Cons(x,xs')=>case D.force ys of Q.Nil=>Q.Nil
     | Q.Cons(y,ys')=>case D.force zs of Q.Nil=>Q.Nil
       | Q.Cons(z,zs')=>Q.Cons(D.delay(fn()=>(D.force x,D.force y,D.force z)),zip3 xs' ys' zs'))
 val daynames=singleton(chars " Su Mo Tu We Th Fr Sa")
 fun cal year=
   let val banner=above(singleton(cjustify 75(show year)))(emptyPic 1 75)
       fun pic(name,first,days)=above(singleton(cjustify 21 name))
         (above daynames(block 7(dates first days)))
       fun pad picture=let val side=emptyPic 8 2
                       in above(beside side(beside picture side))(emptyPic 1 25)end
       val months=zip3 monthNames(firstDays year)(monthLengths year)
   in above banner(block 3(Q.map(fn month=>pad(pic month))months))end
 fun unlines picture=D.delay(fn()=>case D.force picture of Q.Nil=>Q.Nil
   | Q.Cons(row,rest)=>D.force(Q.append(D.force row)(Q.cons(Q.value #"\n")(unlines rest))))
 fun rendered year=unlines(cal year)
 fun text year=String.implode(Q.toList(rendered year))
 fun size year=length(rendered year)
end
