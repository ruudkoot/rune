functor BenchWave4Fn(D:BENCH_SUSPEND)=
struct
 structure A=BenchWaveArrayFn(D)
 type column=real A.array
 type matrix=column A.array
 datatype tripleNode=Triple of matrix*matrix*matrix
 type triple=tripleNode D.t
 type solution=triple*triple
 fun tabulate f(xBounds,yBounds)=A.tabulate(fn i=>A.tabulate(f i)yBounds)xBounds
 fun sub matrix i j=A.sub(A.sub matrix i)j
 fun firstColumn matrix=A.defer(fn()=>A.sub matrix(#1(A.bounds matrix)))
 fun lastColumn matrix=A.defer(fn()=>A.sub matrix(#2(A.bounds matrix)))
 val imax=7 val jmax=7 val k=4
 val deltaX=10000.0 val deltaY=10000.0 val deltaT=800.0
 val coriolisRate=0.000125 val gamma=0.0000032 val psi=0.0
 val gravity=9.8 val lambda=0.0024 val wind=0.0
 val cux=gravity*(deltaT/(2.0*deltaX))
 val cuy=gravity*(deltaT/(2.0*deltaY))
 val ccr=coriolisRate*(deltaT/4.0)
 val cfr=2.0*deltaT
 val windX=gamma*(wind*(wind*Math.cos psi))
 val windY=gamma*(wind*(wind*Math.sin psi))
 val chx=deltaT/(4.0*deltaX)
 val chy=deltaT/(4.0*deltaY)
 fun depth i j=30.0
 fun updateU u v h i j=
   if i=0 orelse i=imax+1 then 0.0
   else let val height=cux*(sub h i j-sub h(i-1)j)
            val v1=sub v(i-1)j val v2=sub v(i-1)(j+1)
            val v3=sub v i j val v4=sub v i(j+1)
            val coriolis=ccr*(v1+(v2+(v3+v4)))
            val bottom=lambda*sub u i j
            val friction=cfr*((bottom-windX)/(depth i j+depth i(j+1)))
        in (sub u i j-height)+(coriolis-friction)end
 fun updateV u v h i j=
   if j=0 orelse j=jmax+1 then 0.0
   else let val height=cuy*(sub h i j-sub h i(j-1))
            val u1=sub u i(j-1)val u2=sub u(i+1)(j-1)
            val u3=sub u i j val u4=sub u(i+1)j
            val coriolis=ccr*(u1+(u2+(u3+u4)))
            val bottom=lambda*sub v i j
            val friction=cfr*((bottom-windY)/(depth i j+depth(i+1)j))
        in (sub v i j-height)-(coriolis+friction)end
 fun updateH u v h i j=
   let val d1=(depth(i+1)j+depth(i+1)(j+1))*sub u(i+1)j
       val d2=(depth i j+depth i(j+1))*sub u i j
       val d3=(depth i(j+1)+depth(i+1)(j+1))*sub v i(j+1)
       val d4=(depth i j+depth(i+1)j)*sub v i j
   in (sub h i j-chx*(d1-d2))-chy*(d3-d4)end
 val dul=((0,4),(0,7))val dvl=((0,3),(0,8))val dhl=((0,3),(0,7))
 val dur=((5,8),(0,7))val dvr=((4,7),(0,8))val dhr=((4,7),(0,7))
 fun u0 i j=0.0 fun v0 i j=0.0
 fun h0 i j=Real.fromInt(3*i)/Real.fromInt imax
 val initialLeft=D.delay(fn()=>Triple(tabulate u0 dul,tabulate v0 dvl,tabulate h0 dhl))
 val initialRight=D.delay(fn()=>Triple(tabulate u0 dur,tabulate v0 dvr,tabulate h0 dhr))
 fun firstBorders triple=
   (A.defer(fn()=>let val Triple(_,v,_)=D.force triple in firstColumn v end),
    A.defer(fn()=>let val Triple(_,_,h)=D.force triple in firstColumn h end))
 fun lastBorder triple=A.defer(fn()=>let val Triple(u,_,_)=D.force triple in lastColumn u end)
 fun fu triple(vc,hc)=D.delay(fn()=>
   let val Triple(u,v,h)=D.force triple
       val vExtended=A.append v vc val hExtended=A.append h hc
   in Triple(tabulate(updateU u vExtended hExtended)dul,v,h)end)
 fun fv triple=D.delay(fn()=>let val Triple(u,v,h)=D.force triple
   in Triple(u,tabulate(updateV u v h)dvl,h)end)
 fun fh triple=D.delay(fn()=>let val Triple(u,v,h)=D.force triple
   in Triple(u,v,tabulate(updateH u v h)dhl)end)
 fun gu triple=D.delay(fn()=>let val Triple(u,v,h)=D.force triple
   in Triple(tabulate(updateU u v h)dur,v,h)end)
 fun gv triple uc=D.delay(fn()=>
   let val Triple(u,v,h)=D.force triple val extended=A.prepend u uc
   in Triple(u,tabulate(updateV extended v h)dvr,h)end)
 fun gh triple uc=D.delay(fn()=>
   let val Triple(u,v,h)=D.force triple val extended=A.prepend u uc
   in Triple(u,v,tabulate(updateH extended v h)dhr)end)
 fun solve steps=
   let fun loop left right borders 0=(left,right)
         |loop left right borders n=
            let val leftU=fu left borders
                val rightU=gu right
                val leftLast=lastBorder leftU
                val leftNext=fh(fv leftU)
                val rightNext=gh(gv rightU leftLast)leftLast
                val bordersNext=firstBorders rightNext
            in loop leftNext rightNext bordersNext(n-1)end
   in loop initialLeft initialRight(firstBorders initialRight)steps end
 fun matrices(left,right)=
   let val Triple(lu,lv,lh)=D.force left val Triple(ru,rv,rh)=D.force right
   in [lu,ru,lv,rv,lh,rh]end
 fun bounds matrix=
   let val(lo,hi)=A.bounds matrix val(low,high)=A.bounds(A.sub matrix lo)
   in(lo,hi,low,high)end
 fun flatten matrix=List.concat(List.map A.values(A.values matrix))
 fun showFix x=
   let val sign=if x<0.0 then "-"else" "
       val i=Real.floor(0.5+Real.abs(x*100.0))
       fun digit n=String.str(Char.chr(Char.ord #"0"+n))
   in if i>999 then"*****"else sign^digit(i div 100 mod 10)^"."^digit(i div 10 mod 10)^digit(i mod 10)end
 fun descriptor(low,high)="["^Int.toString low^".."^Int.toString high^"]"
 fun arrayPrint printValue separator array=
   descriptor(A.bounds array)^String.concat(List.map(fn value=>String.str separator^printValue value)(A.values array))
 fun matrixPrint matrix=arrayPrint(arrayPrint showFix #",") #"\n"matrix
 fun output solution=String.concat(List.map(fn matrix=>matrixPrint matrix^"\n")(matrices solution))
 fun sumcode text=
   let val sum=List.foldl(fn(c,n)=>n+Char.ord c)0(String.explode text)
       val n=String.size text
   in Int.toString(sum+n)^"/"^Int.toString n^"\n"end
end
