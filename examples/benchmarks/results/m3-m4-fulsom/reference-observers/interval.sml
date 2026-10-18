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
(* Duncan Sinclair, copyright 1990-1993; original permission notices retained.
 * Reachable binary64 interval fragment; source comparisons are interval-specific. *)
functor BenchFulsomIntervalFn(D:BENCH_SUSPEND)=
struct
 datatype node=Point of real D.t|Range of real D.t*real D.t
 type t=node D.t
 fun point x=D.delay(fn()=>Point(D.delay(fn()=>x)))
 fun range a b=D.delay(fn()=>Range(D.delay(fn()=>a),D.delay(fn()=>b)))
 fun mapPoint f a=D.delay(fn()=>case D.force a of Point x=>Point(D.delay(fn()=>f(D.force x)))|Range _=>raise Fail"point interval required")
 fun unpoint a=case D.force a of Point x=>D.force x|_=>raise Fail"point interval required"
 fun lower a=case D.force a of Point x=>D.force x|Range(x,_)=>D.force x
 fun upper a=case D.force a of Point x=>D.force x|Range(_,x)=>D.force x
 fun less a b=upper a<lower b
 fun greater a b=lower a>upper b
 fun lessEqual a b=upper a<=upper b
 fun greaterEqual a b=lower a>=lower b
 fun add a b=D.delay(fn()=>case(D.force a,D.force b)of
    (Point x,Point y)=>Point(D.delay(fn()=>D.force x+D.force y))
   |(Range(a,b),Range(c,d))=>Range(D.delay(fn()=>D.force a+D.force c),D.delay(fn()=>D.force b+D.force d))
   |(Point a,Range(c,d))=>Range(D.delay(fn()=>D.force a+D.force c),D.delay(fn()=>D.force a+D.force d))
   |(Range(a,b),Point c)=>Range(D.delay(fn()=>D.force a+D.force c),D.delay(fn()=>D.force b+D.force c)))
 fun negative a=D.delay(fn()=>case D.force a of
    Point x=>Point(D.delay(fn()=> ~(D.force x)))
   |Range(a,b)=>Range(D.delay(fn()=> ~(D.force b)),D.delay(fn()=> ~(D.force a))))
 fun subtract a b=add a(negative b)
 fun square a=D.delay(fn()=>case D.force a of
    Point x=>Point(D.delay(fn()=>D.force x*D.force x))
   |Range(a,b)=>
      if D.force a>0.0 then Range(D.delay(fn()=>D.force a*D.force a),D.delay(fn()=>D.force b*D.force b))
      else if D.force b<0.0 then Range(D.delay(fn()=>D.force b*D.force b),D.delay(fn()=>D.force a*D.force a))
      else Range(D.delay(fn()=>0.0),D.delay(fn()=>Real.max(D.force a*D.force a,D.force b*D.force b))))
 fun minimum a b=D.delay(fn()=>case(D.force a,D.force b)of
    (Point a,Point c)=>Point(D.delay(fn()=>Real.min(D.force a,D.force c)))
   |(Range(a,b),Range(c,d))=>Range(D.delay(fn()=>Real.min(D.force a,D.force c)),D.delay(fn()=>Real.min(D.force b,D.force d)))
   |(Point a,Range(c,d))=>if D.force a<D.force c then Point a
       else Range(c,D.delay(fn()=>Real.min(D.force a,D.force d)))
   |(Range(a,b),Point c)=>if D.force c<D.force a then Point c
       else Range(a,D.delay(fn()=>Real.min(D.force c,D.force b))))
 fun bottom a=D.delay(fn()=>case D.force a of Range(x,y)=>
   Range(x,D.delay(fn()=>(D.force x+D.force y)/2.0))|_=>raise Fail"range interval required")
 fun top a=D.delay(fn()=>case D.force a of Range(x,y)=>
   Range(D.delay(fn()=>(D.force x+D.force y)/2.0),y)|_=>raise Fail"range interval required")
 fun topBit a=D.delay(fn()=>case D.force a of Range(x,y)=>
   Range(D.delay(fn()=>(D.force x+D.force y)/2.0-0.001),y)|_=>raise Fail"range interval required")
 fun up a=D.delay(fn()=>case D.force a of Range(_,y)=>Point y|_=>raise Fail"range interval required")
 fun mid1 a=D.delay(fn()=>case D.force a of Range(x,y)=>
   Point(D.delay(fn()=>D.force x+(D.force y-D.force x)/3.0))|_=>raise Fail"range interval required")
 fun mid2 a=D.delay(fn()=>case D.force a of Range(x,y)=>
   Point(D.delay(fn()=>D.force y-(D.force y-D.force x)/3.0))|_=>raise Fail"range interval required")
end
