(* Fourier benchmarks by Rex Page, Amoco Production Research, September 1992.
   Port of the pinned Haskell definitions; original correspondence is retained. *)
functor BenchFFT2Fn(D:BENCH_SUSPEND) =
struct
 structure L=BenchLazy
 structure S=BenchStream
 type number=real D.t
 datatype complex=C of number*number
 fun value(x:number)=D.force x
 fun number(x:real)=D.delay(fn()=>x)
 fun addNum(a,b)=D.delay(fn()=>value a+value b)
 fun mulNum(a,b)=D.delay(fn()=>value a*value b)
 val zero=number 0.0
 val one=number 1.0
 fun realPart(C(a,_))=a
 fun imagPart(C(_,b))=b
 fun complexAdd(C(a,b),C(c,d))=C(addNum(a,c),addNum(b,d))
 fun complexSub(C(a,b),C(c,d))=C(D.delay(fn()=>value a-value c),D.delay(fn()=>value b-value d))
 fun complexMul(C(a,b),C(c,d))=C(D.delay(fn()=>value a*value c-value b*value d),
   D.delay(fn()=>value a*value d+value b*value c))
 fun conjugate(C(a,b))=C(a,D.delay(fn()=> ~(value b)))
 fun exponent value=if Real.==(value,0.0)then 0 else #exp(Real.toManExp value)
 fun scaled n value=Real.fromManExp{man=value,exp=n}
 fun divide(C(a,b),C(c,d))=
   let val k=L.delay(fn()=>Int.max(exponent(value c),exponent(value d)))
       val c'=D.delay(fn()=>scaled(~(L.force k))(value c))
       val d'=D.delay(fn()=>scaled(~(L.force k))(value d))
       val denominator=D.delay(fn()=>value c*value c'+value d*value d')
   in C(D.delay(fn()=>(value a*value c'+value b*value d')/value denominator),
     D.delay(fn()=>(value b*value c'-value a*value d')/value denominator))end
 fun magnitude(C(x,y))=D.delay(fn()=>
   let val k=Int.max(exponent(value x),exponent(value y))
       val a=scaled(~k)(value x)val b=scaled(~k)(value y)
   in scaled k(Math.sqrt(a*a+b*b))end)
 fun length values=
   let fun loop n values=case L.force values of S.Nil=>n|S.Cons(_,rest)=>loop(n+1)rest
   in loop 0 values end
 fun drop 0 values=values
   |drop n values=case L.force values of S.Nil=>S.empty()|S.Cons(_,rest)=>drop(n-1)rest
 fun takeWhile test values=L.delay(fn()=>case L.force values of S.Nil=>S.Nil
   |S.Cons(first,rest)=>if test(L.force first)then S.Cons(first,takeWhile test rest)else S.Nil)
 fun every n values=
   S.map S.head(takeWhile(fn rest=>case L.force rest of S.Nil=>false|_=>true)
     (S.iterate(fn rest=>drop n rest)(L.delay(fn()=>values))))
 fun cycle values=S.fix(fn result=>L.force(S.append values result))
 fun repeat count values=if count<=0 then S.empty()else S.append values(repeat(count-1)values)
 fun numbers count=S.fromList(List.tabulate(count,fn i=>i))
 fun thetas count=S.map(fn k=>D.delay(fn()=>(2.0*Math.pi/Real.fromInt count)*Real.fromInt k))(numbers count)
 fun roots count=
   let val angles=thetas count
   in S.zipWith(fn(a,b)=>C(D.delay(fn()=>Math.cos(value a)),D.delay(fn()=>Math.sin(value b))))angles angles end
 fun norm values=D.delay(fn()=>
   let val squares=S.map(fn z=>let val m=magnitude z in mulNum(m,m)end)values
       val sum=S.foldl(fn(x,total)=>addNum(total,x))zero squares
   in Math.sqrt(value sum)end)
 fun distance a b=norm(S.zipWith complexSub a b)
 fun ffth xs us=L.delay(fn()=>
   let val count=length xs
   in if count=1 then L.force xs
      else if count>1 then
        let val uEvens=every 2 us
            val evens=ffth(every 2 xs)uEvens
            val odds=ffth(every 2(S.tail xs))uEvens
        in L.force(S.zipWith complexAdd(cycle evens)
          (S.zipWith complexMul us(cycle odds)))end
      else raise Fail "source fft2 fast transform requires a nonempty input"end)
 fun fft xs=
   let val count=length xs val coefficient=divide(C(one,zero),C(number(Real.fromInt count),zero))
   in S.map(fn z=>complexMul(coefficient,z))(ffth xs(S.map conjugate(roots count)))end
 fun fftinv xs=ffth xs(roots(length xs))
 val primes=
   let fun sieve values=
         let val p=S.head values
         in S.filter(fn n=>n mod p<>0)(S.tail values)end
       val candidates=S.iterate(fn n=>n+1)(L.delay(fn()=>2))
   in S.map S.head(S.iterate sieve(L.delay(fn()=>candidates)))end
 fun factors count=
   let fun loop n candidates=L.delay(fn()=>
         let val p=S.head candidates
         in if n=1 then S.Nil
            else if n mod p=0 then S.Cons(L.delay(fn()=>p),loop(n div p)candidates)
            else L.force(loop n(S.tail candidates))end)
   in loop count primes end
 fun sumComplex values=S.foldl(fn(z,total)=>complexAdd(total,z))(C(zero,zero))values
 fun sfth count xs us=S.map(fn k=>
   sumComplex(S.zipWith complexMul xs(every k us)))(numbers count)
 fun transpose rows=L.delay(fn()=>
   let val nonempty=S.filter(fn row=>case L.force row of S.Nil=>false|_=>true)rows
   in case L.force nonempty of S.Nil=>S.Nil
     |_=>S.Cons(L.delay(fn()=>S.map S.head nonempty),transpose(S.map S.tail nonempty))end)
 fun dfth fs xs us=L.delay(fn()=>case L.force fs of S.Nil=>raise Match
   |S.Cons(first,rest)=>
      let val factor=L.force first
      in case L.force rest of S.Nil=>L.force(sfth factor xs us)
        |_=>let val sections=S.map(fn k=>
              let val section=dfth rest(every factor(drop k xs))(every factor us)
              in S.zipWith complexMul(repeat factor section)(every k us)end)(numbers factor)
            in L.force(S.map sumComplex(transpose sections))end
      end)
 fun dft xs=
   let val count=length xs val coefficient=divide(C(one,zero),C(number(Real.fromInt count),zero))
   in S.map(fn z=>complexMul(coefficient,z))
     (dfth(factors count)xs(cycle(S.map conjugate(roots count))))end
 fun dftinv xs=
   let val count=length xs
   in dfth(factors count)xs(cycle(roots count))end
 fun sft xs=
   let val count=length xs val coefficient=divide(C(one,zero),C(number(Real.fromInt count),zero))
   in S.map(fn z=>complexMul(coefficient,z))(sfth count xs(cycle(S.map conjugate(roots count))))end
 fun sct xs=
   let val count=length xs
   in S.map(fn k=>
     let val coefficient=D.delay(fn()=>Real.fromInt k)
         val cosines=S.map(fn angle=>D.delay(fn()=>Math.cos(value coefficient*value angle)))(thetas count)
         val products=S.zipWith mulNum xs cosines
     in S.foldl(fn(x,total)=>addNum(total,x))zero products end)(numbers count)end
 fun ramp bound=
   (* Haskell Enum Double permits the final endpoint plus half a step. *)
   let val limit=bound-1.0+0.5
       fun loop k=L.delay(fn()=>if Real.fromInt k>limit then S.Nil
         else S.Cons(L.delay(fn()=>number(Real.fromInt k)),loop(k+1)))
   in loop 0 end
 fun run bound=
   let fun complex()=S.map(fn x=>C(x,zero))(ramp bound)
       val first=D.delay(fn()=>
         let val signal=complex()in value(distance signal(fftinv(fft signal)))end)
       val second=D.delay(fn()=>
         let val signal=complex()in value(distance signal(dftinv(dft signal)))end)
       val third=D.delay(fn()=>value(S.foldl(fn(x,sum)=>addNum(sum,x))zero(sct(ramp bound))))
   in[value first,value second,value third]end
end
