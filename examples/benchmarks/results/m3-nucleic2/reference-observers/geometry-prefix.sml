(* Open prefix: nofib Hartel nucleic2, selected boxed Float arithmetic. *)
functor BenchNucleic2Fn(structure D:BENCH_SUSPEND val shared:bool)=struct
 structure L=BenchLazy
 structure F=BenchIdaFiniteFn(D)
 structure R=struct
   val round=BenchMandelSingle.round
   fun add(a:real,b)=round(a+b)
   fun sub(a:real,b)=round(a-b)
   fun mul(a:real,b)=round(a*b)
   fun negative(a:real)= ~a
   fun sqrt x=round(Math.sqrt x)
   fun sin x=round(Math.sin x)
   fun cos x=round(Math.cos x)
   fun divide(a:real,b)=round(a/b)
   fun atan x=round(Math.atan x)
   val pi=round Math.pi
   fun negativeZero x=Real.==(x,0.0)andalso Real.signBit x
   (* GHC 9.4.7 RealFloat's actual default; Float does not override it. *)
   fun atan2(y,x)=
     if x>0.0 then atan(divide(y,x))
     else if Real.==(x,0.0)andalso y>0.0 then divide(pi,2.0)
     else if x<0.0 andalso y>0.0 then add(pi,atan(divide(y,x)))
     else if(x<=0.0 andalso y<0.0)orelse(x<0.0 andalso negativeZero y)orelse
            (negativeZero x andalso negativeZero y)then negative(atan2(negative y,x))
     else if Real.==(y,0.0)andalso(x<0.0 orelse negativeZero x)then pi
     else if Real.==(x,0.0)andalso Real.==(y,0.0)then y else add(x,y)
 end
 type scalar=real D.t
 datatype pointNode=Pt of scalar*scalar*scalar
 type pt=pointNode D.t
 datatype transformNode=Tfo of scalar*scalar*scalar*scalar*scalar*scalar*
      scalar*scalar*scalar*scalar*scalar*scalar
 type tfo=transformNode D.t
 datatype specificNode=A of pt*pt*pt*pt*pt*pt*pt*pt
    |C of pt*pt*pt*pt*pt*pt|G of pt*pt*pt*pt*pt*pt*pt*pt*pt|U of pt*pt*pt*pt*pt
 type specific=specificNode D.t
 datatype nucleotideNode=Nuc of tfo*tfo*tfo*tfo*
      pt*pt*pt*pt*pt*pt*pt*pt*pt*pt*pt*pt*pt*
      pt*pt*pt*pt*pt*pt*pt*pt*pt*pt*pt*pt*specific
 type nuc=nucleotideNode D.t
 fun scalar value=D.delay(fn()=>R.round value)
 fun real value=D.force value
 fun pt_sub a b=D.delay(fn()=>
   let val Pt(x1,y1,z1)=D.force a val Pt(x2,y2,z2)=D.force b
   in Pt(D.delay(fn()=>R.sub(real x1,real x2)),
         D.delay(fn()=>R.sub(real y1,real y2)),
         D.delay(fn()=>R.sub(real z1,real z2)))end)
 fun pt_dist a b=D.delay(fn()=>
   let val Pt(x1,y1,z1)=D.force a val Pt(x2,y2,z2)=D.force b
       val dx=D.delay(fn()=>R.sub(real x1,real x2))
       val dy=D.delay(fn()=>R.sub(real y1,real y2))
       val dz=D.delay(fn()=>R.sub(real z1,real z2))
   in R.sqrt(R.add(R.add(R.mul(real dx,real dx),R.mul(real dy,real dy)),R.mul(real dz,real dz)))end)
 fun pt_phi p=D.delay(fn()=>
   let val Pt(x,y,z)=D.force p val b=D.delay(fn()=>R.atan2(real x,real z))
   in R.atan2(R.add(R.mul(R.cos(real b),real z),R.mul(R.sin(real b),real x)),real y)end)
 fun pt_theta p=D.delay(fn()=>let val Pt(x,_,z)=D.force p in R.atan2(real x,real z)end)
