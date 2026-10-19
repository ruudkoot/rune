structure BenchSmallpt =
struct
  type vector=real*real*real
  type ray=vector*vector
  datatype reflection=Diffuse|Specular|Refract
  datatype sphere=Sphere of real*vector*vector*vector*reflection
  val zero:vector=(0.0,0.0,0.0)
  fun add((a,b,c):vector,(x,y,z):vector)=(a+x,b+y,c+z)
  fun sub((a,b,c):vector,(x,y,z):vector)=(a-x,b-y,c-z)
  fun mul((a,b,c):vector,(x,y,z):vector)=(a*x,b*y,c*z)
  fun cross((a,b,c):vector,(x,y,z):vector)=(b*z-c*y,c*x-a*z,a*y-b*x)
  fun scale((a,b,c):vector)x=(a*x,b*x,c*x)
  fun dot((a,b,c):vector,(x,y,z):vector)=a*x+b*y+c*z
  fun length(a,b,c)=Math.sqrt(a*a+b*b+c*c)
  fun normalize v=scale v(1.0/length v)
  fun maximum(a,b,c)=Real.max(a,Real.max(b,c))
  fun clamp x=if x<0.0 then 0.0 else if x>1.0 then 1.0 else x
  val scene=Vector.fromList[
    Sphere(1.0E5,(1.0E5+1.0,40.8,81.6),zero,(0.75,0.25,0.25),Diffuse),
    Sphere(1.0E5,(~1.0E5+99.0,40.8,81.6),zero,(0.25,0.25,0.75),Diffuse),
    Sphere(1.0E5,(50.0,40.8,1.0E5),zero,(0.75,0.75,0.75),Diffuse),
    Sphere(1.0E5,(50.0,40.8,~1.0E5+170.0),zero,zero,Diffuse),
    Sphere(1.0E5,(50.0,1.0E5,81.6),zero,(0.75,0.75,0.75),Diffuse),
    Sphere(1.0E5,(50.0,~1.0E5+81.6,81.6),zero,(0.75,0.75,0.75),Diffuse),
    Sphere(16.5,(27.0,16.5,47.0),zero,(0.999,0.999,0.999),Specular),
    Sphere(16.5,(73.0,16.5,78.0),zero,(0.999,0.999,0.999),Refract),
    Sphere(600.0,(50.0,681.6-0.27,81.6),(12.0,12.0,12.0),zero,Diffuse)]
  fun intersect((origin,direction):ray)(Sphere(radius,position,_,_,_))=
    let val opv=sub(position,origin)
        val b=dot(opv,direction)
        val det=b*b-dot(opv,opv)+radius*radius
    in if det<0.0 then Real.posInf
       else let val root=Math.sqrt det val near=b-root val far=b+root
         in if near>1.0E~4 then near else if far>1.0E~4 then far else Real.posInf end end
  fun intersects ray=
    let val first=Vector.sub(scene,0)
        fun loop i best=if i=Vector.length scene then best else
          let val next=Vector.sub(scene,i)val distance=intersect ray next
          in loop(i+1)(if distance< #1 best then(distance,next)else best)end
    in loop 1(intersect ray first,first)end
  fun seed y=
    let val value=Word64.fromInt y
    in Word64.<<(Word64.*(Word64.*(value,value),value),0w32)end
  fun randomStep state=
    let val next=Word64.+(Word64.*(0wx5deece66d,state),0w11)
    in(next,Word64.andb(next,0wxffffffffffff))end
  fun random state=
    let val(next,masked)=randomStep(!state)
        val _=state:=next
        val high=Word64.toInt(Word64.>>(masked,0w24))
        val low=Word64.toInt(Word64.andb(masked,0wxffffff))
    in Real.fromInt high/16777216.0+Real.fromInt low/281474976710656.0 end
  fun radiance(ray as(origin,direction))depth state=
    let val(distance,Sphere(_,position,emission,color,material))=intersects ray
    in if Real.==(distance,Real.posInf)then zero else
      let val x=add(origin,scale direction distance)
          val normal=normalize(sub(x,position))
          val oriented=if dot(normal,direction)<0.0 then normal else scale normal(~1.0)
          val nextDepth=depth+1
          fun continue filter=case material of
              Diffuse=>
                let val r1=2.0*Math.pi*random state val r2=random state
                    val r2s=Math.sqrt r2
                    val w as(wx,_,_)=oriented
                    val u=normalize(cross((if Real.abs wx>0.1 then(0.0,1.0,0.0)else(1.0,0.0,0.0)),w))
                    val v=cross(w,u)
                    val next=normalize(add(add(scale u(Math.cos r1*r2s),scale v(Math.sin r1*r2s)),scale w(Math.sqrt(1.0-r2))))
                    val incoming=radiance(x,next)nextDepth state
                in add(emission,mul(filter,incoming))end
            | Specular=>
                let val next=sub(direction,scale normal(2.0*dot(normal,direction)))
                    val incoming=radiance(x,next)nextDepth state
                in add(emission,mul(filter,incoming))end
            | Refract=>
                let val reflected=(x,sub(direction,scale normal(2.0*dot(normal,direction))))
                    val into=dot(normal,oriented)>0.0
                    val nc=1.0 val nt=1.5
                    val ratio=if into then nc/nt else nt/nc
                    val ddn=dot(direction,oriented)
                    val cosine=1.0-ratio*ratio*(1.0-ddn*ddn)
                in if cosine<0.0 then
                    let val incoming=radiance reflected nextDepth state
                    in add(emission,mul(filter,incoming))end
                   else let
                     val transmitted=normalize(sub(scale direction ratio,
                       scale normal((if into then 1.0 else ~1.0)*(ddn*ratio+Math.sqrt cosine))))
                     val a=nt-nc val b=nt+nc val r0=a*a/(b*b)
                     val c=1.0-(if into then ~ddn else dot(transmitted,normal))
                     val re=r0+(1.0-r0)*c*c*c*c*c val tr=1.0-re
                     val probability=0.25+0.5*re
                     val rp=re/probability val tp=tr/(1.0-probability)
                     val incoming=if depth>2 then
                       let val choice=random state
                       in if choice<probability then scale(radiance reflected nextDepth state)rp
                          else scale(radiance(x,transmitted)nextDepth state)tp end
                       else let val reflectedLight=scale(radiance reflected nextDepth state)re
                                val transmittedLight=scale(radiance(x,transmitted)nextDepth state)tr
                            in add(reflectedLight,transmittedLight)end
                   in add(emission,mul(filter,incoming))end end
      in if nextDepth>5 then
          let val choice=random state val probability=maximum color
          in if choice<probability then continue(scale color(1.0/probability))else emission end
         else continue color end end
  fun render width height samples emitRow=
    let val origin=(50.0,52.0,295.6)
        val direction=normalize(0.0,~0.042612,~1.0)
        val cx=(Real.fromInt width*0.5135/Real.fromInt height,0.0,0.0)
        val cy=scale(normalize(cross(cx,direction)))0.5135
        fun row y=
          let val state=ref(seed y)
              fun pixel x=
                let fun subpixels sy sx total=
                      if sy=2 then total else if sx=2 then subpixels(sy+1)0 total
                      else let
                        fun sample i accumulated=if i=samples then accumulated else
                          let val r1=2.0*random state
                              val dx=if r1<1.0 then Math.sqrt r1-1.0 else 1.0-Math.sqrt(2.0-r1)
                              val r2=2.0*random state
                              val dy=if r2<1.0 then Math.sqrt r2-1.0 else 1.0-Math.sqrt(2.0-r2)
                              val d=add(add(scale cx(((Real.fromInt sx+0.5+dx)/2.0+Real.fromInt x)/Real.fromInt width-0.5),
                                            scale cy(((Real.fromInt sy+0.5+dy)/2.0+Real.fromInt y)/Real.fromInt height-0.5)),direction)
                              val light=radiance(add(origin,scale d 140.0),normalize d)0 state
                          in sample(i+1)(add(accumulated,scale light(1.0/Real.fromInt samples)))end
                        val(rr,rg,rb)=sample 0 zero
                      in subpixels sy(sx+1)(add(total,scale(clamp rr,clamp rg,clamp rb)0.25))end
                in subpixels 0 0 zero end
              fun pixels x=if x=width then[]else let val value=pixel x in value::pixels(x+1)end
              val values=pixels 0
          in emitRow y values end
        fun rows y=if y<0 then()else(row y;rows(y-1))
    in rows(height-1)end
end
