(* ALMABENCH 1.0.1, Shawn Wagner, from Scott Robert Ladd's C++/Java versions.
   No rights reserved. This is public domain software, for use by anyone.
   Original numerical algorithm: Simon et al., A&A 282, 663 (1994). *)
structure BenchAlma =
struct
  structure T=BenchAlmaTables
  fun get table planet index=RealArray.sub(Array.sub(table,planet),index)
  fun anpm angle=
    let val w=Real.rem(angle,T.twopi)
    in if Real.abs w>=T.pic then if angle<0.0 then w+T.twopi else w-T.twopi else w end
  fun planetPV epoch np pv=
    let val t=((RealArray.sub(epoch,0)-T.j2000)+RealArray.sub(epoch,1))/T.jmillenia
        val da=ref(get T.a np 0+(get T.a np 1+get T.a np 2*t)*t)
        val dl=ref((3600.0*get T.dlm np 0+(get T.dlm np 1+get T.dlm np 2*t)*t)*T.a2r)
        val de=get T.e np 0+(get T.e np 1+get T.e np 2*t)*t
        val dp=anpm((3600.0*get T.pi np 0+(get T.pi np 1+get T.pi np 2*t)*t)*T.a2r)
        val di=(3600.0*get T.dinc np 0+(get T.dinc np 1+get T.dinc np 2*t)*t)*T.a2r
        val doh=anpm((3600.0*get T.omega np 0+(get T.omega np 1+get T.omega np 2*t)*t)*T.a2r)
        val dmu=0.35953620*t
        val kp=Array.sub(T.kp,np)val kq=Array.sub(T.kq,np)
        val ca=Array.sub(T.ca,np)val sa=Array.sub(T.sa,np)
        val cl=Array.sub(T.cl,np)val sl=Array.sub(T.sl,np)
        fun loop k=if k>7 then()else
          let val arga=RealArray.sub(kp,k)*dmu val argl=RealArray.sub(kq,k)*dmu
              val _=da:= !da+(RealArray.sub(ca,k)*Math.cos arga+RealArray.sub(sa,k)*Math.sin arga)*0.0000001
              val _=dl:= !dl+(RealArray.sub(cl,k)*Math.cos argl+RealArray.sub(sl,k)*Math.sin argl)*0.0000001
          in loop(k+1)end
        val _=loop 0
        val arga=RealArray.sub(kp,8)*dmu
        val _=da:= !da+t*(RealArray.sub(ca,8)*Math.cos arga+RealArray.sub(sa,8)*Math.sin arga)*0.0000001
        fun extra k=if k>9 then()else
          let val argl=RealArray.sub(kq,k)*dmu
              val _=dl:= !dl+t*(RealArray.sub(cl,k)*Math.cos argl+RealArray.sub(sl,k)*Math.sin argl)*0.0000001
          in extra(k+1)end
        val _=extra 8
        val _=dl:=Real.rem(!dl,T.twopi)
        val am= !dl-dp
        val ae=ref(am+de*Math.sin am)
        val k=ref 0
        val dae=ref((am- !ae+de*Math.sin(!ae))/(1.0-de*Math.cos(!ae)))
        val _=ae:= !ae+ !dae
        val _=k:= !k+1
        fun solve()=if !k<10 orelse Real.abs(!dae)>=1.0E~12 then
          (dae:=(am- !ae+de*Math.sin(!ae))/(1.0-de*Math.cos(!ae));
           ae:= !ae+ !dae;k:= !k+1;solve())else()
        val _=solve()
        val ae2= !ae/2.0
        val at=2.0*Math.atan2(Math.sqrt((1.0+de)/(1.0-de))*Math.sin ae2,Math.cos ae2)
        val r= !da*(1.0-de*Math.cos(!ae))
        val speed=T.gaussk*Math.sqrt((1.0+1.0/RealArray.sub(T.amas,np))/(!da* !da* !da))
        val si2=Math.sin(di/2.0)
        val xq=si2*Math.cos doh val xp=si2*Math.sin doh val tl=at+dp
        val xsw=Math.sin tl val xcw=Math.cos tl
        val xm2=2.0*(xp*xcw-xq*xsw)
        val xf= !da/Math.sqrt(1.0-de*de)
        val ci2=Math.cos(di/2.0)
        val xms=(de*Math.sin dp+xsw)*xf val xmc=(de*Math.cos dp+xcw)*xf
        val xpxq2=2.0*xp*xq
        val x=r*(xcw-xm2*xp)val y=r*(xsw+xm2*xq)val z=r*(~xm2*ci2)
        val position=Array.sub(pv,0)val velocity=Array.sub(pv,1)
        val _=RealArray.update(position,0,x)
        val _=RealArray.update(position,1,y*T.coseps-z*T.sineps)
        val _=RealArray.update(position,2,y*T.sineps+z*T.coseps)
        val x=speed*((~1.0+2.0*xp*xp)*xms+xpxq2*xmc)
        val y=speed*((1.0-2.0*xq*xq)*xmc-xpxq2*xms)
        val z=speed*(2.0*ci2*(xp*xms+xq*xmc))
        val _=RealArray.update(velocity,0,x)
        val _=RealArray.update(velocity,1,y*T.coseps-z*T.sineps)
    in RealArray.update(velocity,2,y*T.sineps+z*T.coseps)end
  fun raDecDist state result=
    let val position=Array.sub(state,0)
        val x=RealArray.sub(position,0)val y=RealArray.sub(position,1)val z=RealArray.sub(position,2)
        val _=RealArray.update(result,2,Math.sqrt(x*x+y*y+z*z))
        val _=RealArray.update(result,0,Math.atan2(y,x)*T.r2h)
        val _=if RealArray.sub(result,0)<0.0 then RealArray.update(result,0,RealArray.sub(result,0)+24.0)else()
    in RealArray.update(result,1,Math.asin(z/RealArray.sub(result,2))*T.r2d)end
end
