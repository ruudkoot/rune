(*
 -  Fulsom (The Solid Modeller, written in Haskell)
 -
 -  Copyright 1990,1991,1992,1993 Duncan Sinclair
 -
 - Permissiom to use, copy, modify, and distribute this software for any
 - purpose and without fee is hereby granted, provided that the above
 - copyright notice and this permission notice appear in all copies, and
 - that my name not be used in advertising or publicity pertaining to this
 - software without specific, written prior permission.  I makes no
 - representations about the suitability of this software for any purpose.
 - It is provided ``as is'' without express or implied warranty.
 -
 - Duncan Sinclair 1993.
 -
 - Interval arithmetic package.
 -
 *)
(* Duncan Sinclair, copyright 1990-1993; original per-module permission retained.
 * Reachable coloured-sphere/union CSG kernel selected by both Main programs. *)
functor BenchFulsomFn(D:BENCH_SUSPEND)=
struct
 structure I=BenchFulsomIntervalFn(D)
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 datatype colorNode=RGB of real D.t*real D.t*real D.t
 type color=colorNode D.t
 type xyz=I.t*I.t*I.t
 datatype csgNode=Sphere of real*real*real*real|Colour of color*csgNode L.delay
   |Union of csgNode L.delay*csgNode L.delay
   |Function of(color->xyz->resultNode L.delay)
 and resultNode=Result of I.t*csgNode L.delay*color*bool L.delay
 type csg=csgNode L.delay
 type result=resultNode L.delay
 datatype octNode=OFull of color|OEmpty|OSub of color*octNode L.delay F.seq
 type oct=octNode L.delay
 datatype quadNode=QEmpty|QFull of color|QSub of color*quadNode L.delay F.seq
 type quad=quadNode L.delay
 fun color r g b=D.delay(fn()=>RGB(D.delay(fn()=>r),D.delay(fn()=>g),D.delay(fn()=>b)))
 fun mkcolor r g b=color(Real.fromInt r/255.0)(Real.fromInt g/255.0)(Real.fromInt b/255.0)
 val white=mkcolor 255 255 255
 val black=mkcolor 0 0 0
 val zero=I.point 0.0
 fun dead()=L.delay(fn()=>raise Fail"Evaluated dead csg.")
 fun answer result=D.delay(fn()=>case L.force result of Result(ans,_,_,_)=>D.force ans)
 fun residual result=case L.force result of Result(_,next,_,_)=>next
 fun resultColor result=D.delay(fn()=>case L.force result of Result(_,_,rgb,_)=>D.force rgb)
 fun changed result=case L.force result of Result(_,_,_,flag)=>L.force flag
 fun sphereFunction a b c r=
   let val aa=I.point a val bb=I.point b val cc=I.point c val rr=I.point r
       fun evaluate rgb(x,y,z)=L.delay(fn()=>
         Result(I.subtract(I.add(I.add(I.square(I.subtract x aa))(I.square(I.subtract y bb)))
           (I.square(I.subtract z cc)))(I.square rr),dead(),rgb,L.delay(fn()=>false)))
   in L.delay(fn()=>Function evaluate)end
 fun calc shape rgb coords=L.delay(fn()=>case L.force shape of
     Function f=>L.force(f rgb coords)
    |Sphere(a,b,c,r)=>
       let val next=sphereFunction a b c r
           val result=calc next rgb coords
       in Result(answer result,next,rgb,L.delay(fn()=>true))end
    |Colour(c,inside)=>
       let val result=calc inside c coords
           val next=L.delay(fn()=>if changed result then Colour(c,residual result)
                                 else L.force(dead()))
       in Result(answer result,next,c,L.delay(fn()=>changed result))end
    |Union(a,b)=>
       let val left=calc a rgb coords val right=calc b rgb coords
           val x=answer left val y=answer right
           val new=L.delay(fn()=>changed left orelse changed right)
           val ca=L.delay(fn()=>L.force(if changed left then residual left else a))
           val cb=L.delay(fn()=>L.force(if changed right then residual right else b))
           val newColor=D.delay(fn()=>
             D.force(if I.less x y then resultColor left else if I.greater x y then resultColor right else rgb))
           val next=L.delay(fn()=>if I.less x y then L.force ca
             else if I.greater x y then L.force cb
             else if not(L.force new)then L.force(dead())else Union(ca,cb))
       in Result(I.minimum x y,next,newColor,new)end)
 fun components c=case D.force c of RGB(r,g,b)=>(D.force r,D.force g,D.force b)
 fun light rgb normalValue=D.delay(fn()=>
   let val RGB(r,g,b)=D.force rgb
       val coefficient=L.delay(fn()=>let val(x,y,z)=L.force normalValue
         in Real.max((0.5773*x+0.5773*y+0.5773*z)*(1.0-0.5),0.0)+0.5 end)
   in RGB(D.delay(fn()=>L.force coefficient*D.force r),
          D.delay(fn()=>L.force coefficient*D.force g),
          D.delay(fn()=>L.force coefficient*D.force b))end)
 fun normal shape(x,y,z)=
   let val f0=answer(calc shape black(I.mid1 x,I.mid1 y,I.mid2 z))
       val f1=answer(calc shape black(I.mid2 x,I.mid1 y,I.mid2 z))
       val f2=answer(calc shape black(I.mid1 x,I.mid2 y,I.mid2 z))
       val f3=answer(calc shape black(I.mid1 x,I.mid1 y,I.up z))
       val a=I.unpoint f0
       val x=I.unpoint f1-a val y=I.unpoint f2-a val z=I.unpoint f3-a
       val squares=x*x+y*y+z*z
       val length=if not(Real.==(squares,0.0))then Math.sqrt squares else 1.0
   in(x/length,y/length,z/length)end
 fun shadeColor rgb shape coords=light rgb(L.delay(fn()=>normal shape coords))
 fun octer level shape(coords as(x,y,z))=L.delay(fn()=>
   let val result=calc shape white coords
       val value=answer result
       val next=L.delay(fn()=>L.force(if changed result then residual result else shape))
       fun children()=D.delay(fn()=>
         let val bx=I.bottom x val tx=I.top x val by=I.bottom y val ty=I.top y
             val tz=I.topBit z val bz=I.bottom z
             val regions=[(bx,by,tz),(bx,by,bz),(tx,by,tz),(tx,by,bz),
                          (bx,ty,tz),(bx,ty,bz),(tx,ty,tz),(tx,ty,bz)]
         in D.force(F.fromList(List.map(fn region=>octer(level+1)next region)regions))end)
   in if I.less value zero then OFull(shadeColor(resultColor result)next coords)
      else if I.greater value zero then OEmpty
      else OSub(shadeColor(resultColor result)next coords,children())end)
 fun prune depth oct=L.delay(fn()=>case L.force oct of
      OSub(c,children)=>if depth=0 then OFull c
        else OSub(c,F.map(prune(depth-1))children)
     |other=>other)
 fun octcsg depth shape=prune depth(octer 1 shape(I.range(~2.0)2.0,I.range(~2.0)2.0,I.range(~2.0)2.0))
 fun emptyQuad()=L.delay(fn()=>QEmpty)
 fun child values index=F.nth values index
 fun deferredChild values index=L.delay(fn()=>L.force(child values index))
 fun qo oct quad=L.delay(fn()=>case L.force quad of
      QFull c=>QFull c
     |q=>case L.force oct of
        OEmpty=>q
       |OFull c=>(case q of QSub(old,children)=>
             QSub(old,F.fromList(List.tabulate(4,fn i=>qo oct(deferredChild children i))))
            |_=>QFull c)
       |OSub(c,children)=>
          let val base=case q of QSub(_,old)=>old|_=>F.fromList(List.tabulate(4,fn _=>emptyQuad()))
              val oldColor=case q of QSub(color,_)=>color|_=>c
              val output=F.fromList(List.tabulate(4,fn i=>
                qo(deferredChild children(2*i+1))(qo(deferredChild children(2*i))(deferredChild base i))))
          in QSub(oldColor,output)end)
 fun quadoct oct=qo oct(emptyQuad())
 val pic=
   let val a=L.delay(fn()=>Colour(mkcolor 240 255 240,L.delay(fn()=>Sphere(~0.5,~1.0,1.0,0.8))))
       val b=L.delay(fn()=>Colour(mkcolor 238 130 238,L.delay(fn()=>Sphere(0.5,~1.0,0.0,0.6))))
       val c=L.delay(fn()=>Colour(mkcolor 173 255 47,L.delay(fn()=>Sphere(~0.2,0.5,~0.8,1.2))))
   in L.delay(fn()=>Union(a,L.delay(fn()=>Union(b,c))))end
 structure S=BenchStream
 fun integer x=L.delay(fn()=>x)
 fun cons x xs=S.cons(integer x,xs)
 fun colorWords rgb=
   let val(r,g,b)=components rgb
   in(Real.round(255.5*r),Real.round(255.5*g),Real.round(255.5*b))end
 fun tileWords x y width rgb next=
   let val components=L.delay(fn()=>case D.force rgb of RGB(r,g,b)=>
         (L.delay(fn()=>Real.round(255.5*D.force r)),
          L.delay(fn()=>Real.round(255.5*D.force g)),
          L.delay(fn()=>Real.round(255.5*D.force b))))
       val blue=S.cons(L.delay(fn()=>L.force(#3(L.force components))),next)
       val green=S.cons(L.delay(fn()=>L.force(#2(L.force components))),blue)
       val red=S.cons(L.delay(fn()=>L.force(#1(L.force components))),green)
   in cons x(cons y(cons width red))end
 fun cout x y width quad next=L.delay(fn()=>case L.force quad of
      QEmpty=>L.force next
     |QFull rgb=>L.force(tileWords x y width rgb next)
     |QSub(_,children)=>
       let val half=width div 2
           val last=cout(x+half)(y+half)half(deferredChild children 3)next
           val third=cout x(y+half)half(deferredChild children 2)last
           val second=cout(x+half)y half(deferredChild children 1)third
       in L.force(cout x y half(deferredChild children 0)second)end)
 fun words depth quad=
   let fun power 0 value=value|power n value=power(n-1)(value*2)
       val width=power depth 1
   in cons 3(cons width(cout 0 0 width quad(S.empty())))end
 fun bytes words=L.delay(fn()=>case L.force words of
      S.Nil=>S.Nil
     |S.Cons(value,rest)=>
       let val shared=L.delay(fn()=>let val n=L.force value in(n div 256,n mod 256)end)
           val low=S.cons(L.delay(fn()=> #2(L.force shared)),bytes rest)
       in S.Cons(L.delay(fn()=> #1(L.force shared)),low)end)
 fun picture depth=bytes(words depth(quadoct(octcsg depth pic)))

end
