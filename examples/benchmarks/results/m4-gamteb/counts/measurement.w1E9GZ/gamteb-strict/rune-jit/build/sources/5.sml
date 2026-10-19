(*

      Patricia Fasel
      Los Alamos National Laboratory
      1990 August

 Copyright, 1990, The Regents of the University of California.
 This software was produced under a U.S. Government contract (W-7405-ENG-36)
 by the Los Alamos National Laboratory, which is operated by the University
 of California for the U.S. Department of Energy.  The U.S. Government is
 licensed to use, reproduce, and distribute this software.  Permission is
 granted to the public to copy and use this software without charge, provided
 that this notice and any statement of authorship are reproduced on all
 copies.  Neither the Government nor the University makes any warranty,
 express or implied, or assumes any liability for the use of this software.

*)
functor BenchGamtebMathFn(D:BENCH_SUSPEND) =
struct
  type number=real D.t
  type point=number*number*number
  fun value(x:number)=D.force x
  fun eval f=D.delay f
  fun literal x=eval(fn()=>x)
  val small=0.0000001
  fun random seed=
    let fun remainder x m=x-Real.fromInt((Real.trunc x div m)*m)
        val first=eval(fn()=>remainder(314557.0*value seed+2711.0)65599/65599.0)
        val second=eval(fn()=>remainder(2711.0*value seed+314557.0)71123/71123.0)
    in(first,second)end
  fun distance((x,y,z):point)((u,v,w):point)=
    let fun plane at=eval(fn()=>if Real.==(value v,0.0)orelse value y>=at
          then 100.0 else(at-value y)/value v)
        val cylinder=eval(fn()=>
          if Real.==(value u*value u+value w*value w,0.0)then 100.0
          else if not(Real.==(value u,0.0))then
            let val m=value w/value u val b=value z-m*value x
                val s=m*m+1.0 val r=Math.sqrt(s-b*b)
                val xx=if value u>0.0 then(~m*b+r)/s else(~m*b-r)/s
            in(xx-value x)/value u end
          else if Real.==(value u,0.0)andalso not(Real.==(value v,0.0))then
            let val m=value w/value v val b=value z-m*value y
                val r=Math.sqrt(1.0-value x*value x)
                val yy=if value v>0.0 then(r-b)/m else(~r-b)/m
            in(yy-value y)/value v end
          else if value w>0.0 then Math.sqrt(1.0-value x*value x)-value z
          else ~(Math.sqrt(1.0-value x*value x))-value z)
        fun smaller(a as(d,_),b as(e,_))=if value d<value e then a else b
        val(d,surface)=smaller(smaller((plane 0.0,1),(cylinder,2)),smaller((plane 20.0,3),(plane 30.0,4)))
    in(eval(fn()=>value d+small),surface)end
  fun isotropic seed=
    let val(_,r2)=random seed val(r3,r4)=random r2
        val t1=eval(fn()=>2.0*value r4-1.0)
        val t2=eval(fn()=>2.0*value r3-1.0)
        val radius=eval(fn()=>value t1*value t1+value t2*value t2)
    in if value radius>1.0 then
         (* The source rejection arm's recursive local r1 is self-dependent.
            Preserve that cyclic demand instead of substituting an outer seed. *)
         let val cycle=BenchStream.fix(fn self=>BenchLazy.force self)
         in BenchStream.head cycle end
       else let val u=eval(fn()=>2.0*value radius-1.0)
                val t3=eval(fn()=>Math.sqrt(1.0-value u*value u)/value radius)
            in(u,eval(fn()=>value t1*value t3),eval(fn()=>value t2*value t3))end
    end
  fun rotate(direction as(u,v,w):point)angle seed=
    let val(r1,r2)=random seed val(next,r3)=random r2
        val t1=eval(fn()=>2.0*value r1-1.0)
        val t2=eval(fn()=>2.0*value r3-1.0)
        val radius=eval(fn()=>value t1*value t1+value t2*value t2)
    in if value radius>1.0 then rotate direction angle next
       else let val rr=eval(fn()=>Math.sqrt((1.0-value angle*value angle)/value radius))
                val a=eval(fn()=>value t1*value rr)
                val b=eval(fn()=>value t2*value rr)
                val wsq=eval(fn()=>1.0-value w*value w)
            in if value wsq<small then(a,b,eval(fn()=>value w*value angle))
               else let val s=eval(fn()=>Math.sqrt(value wsq))
                    in(eval(fn()=>value u*value angle+(value a*value u*value w-value b*value v)/value s),
                       eval(fn()=>value v*value angle+(value a*value v*value w-value b*value u)/value s),
                       eval(fn()=>value w*value angle-value a*value s))end
            end
    end
  fun klein energy randomValue=
    let val a=eval(fn()=>1.0/value energy)
        val b=eval(fn()=>2.0*value energy+1.0)
        val c=eval(fn()=>1.0/value b)
        val d=eval(fn()=>Math.ln(value b))
        val f=eval(fn()=>2.0*value energy*(1.0+value energy)*value c*value c+4.0*value a+
          (1.0-2.0*value a*(1.0+value a))*value d)
        fun fit x2 x3 x4 x5 x7=
          1.0+x2*(x2*(2.0*x7+x4-x3+x2*(x5-x7-x4))-x7)
    in if value energy>1.16666667 then
         let val aa=eval(fn()=>1.65898+value a*(0.62537*value a-1.00796))
             val bb=eval(fn()=>value aa/value f)
         in if value randomValue>value bb then
              eval(fn()=>0.3*Math.exp((value d-1.20397)/(1.0-value bb)*(value bb-value randomValue))*value energy)
            else let val cc=eval(fn()=>value aa/(3.63333+value a*(5.44444*value a-4.66667)))
                 in eval(fn()=>fit(value randomValue/value bb)2.1(value cc)1.4(0.5*value aa)*value energy)end
         end
       else let val aa=eval(fn()=>value f/(value b+value c))
                val bb=eval(fn()=>0.5*value f)val cc=eval(fn()=>1.0-value c)
            in eval(fn()=>fit(value randomValue)(3.0*value cc)(value aa)(2.0*value cc)(value bb)*value energy)end
    end
end
