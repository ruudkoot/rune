(* Sequential sphere ray tracer: David J. King, 16 July 1998,
   Haskell port of the Impala Id program. Correspondence retained upstream. *)
functor BenchSphereFn(D:BENCH_SUSPEND) =
struct
  structure L=BenchLazy
  structure S=BenchStream
  type number=real D.t
  datatype vectorNode=V of number*number*number
  type vector=vectorNode L.delay
  datatype light=Directional of vector*vector|Point of vector*vector
  datatype surface=Ambient of vector|Diffuse of vector|Specular of vector
    |Specpow of number|Reflect of number|Transmit of number|Refract of number|Body of vector
  datatype sphere=Sphere of vector*number*surface list
  fun value x=D.force x
  fun number(x:real)=D.delay(fn()=>x)
  fun vector(a,b,c)=L.delay(fn()=>V(number a,number b,number c))
  fun zip f a b=L.delay(fn()=>
    let val V(x,y,z)=L.force a val V(u,v,w)=L.force b
    in V(D.delay(fn()=>f(value x,value u)),D.delay(fn()=>f(value y,value v)),
      D.delay(fn()=>f(value z,value w)))end)
  fun add a b=zip(op +)a b
  fun sub a b=zip(op -)a b
  fun mult a b=zip(op *)a b
  fun scale a k=L.delay(fn()=>
    let val V(x,y,z)=L.force a in V(D.delay(fn()=>value k*value x),
      D.delay(fn()=>value k*value y),D.delay(fn()=>value k*value z))end)
  fun dot a b=D.delay(fn()=>
    let val V(x,y,z)=L.force a val V(u,v,w)=L.force b
    in value x*value u+value y*value v+value z*value w end)
  fun cross a b=L.delay(fn()=>
    let val V(x,y,z)=L.force a val V(u,v,w)=L.force b
    in V(D.delay(fn()=>value y*value w-value z*value v),
         D.delay(fn()=>value z*value u-value x*value w),
         D.delay(fn()=>value x*value v-value y*value u))end)
  fun norm a=
    let val length=D.delay(fn()=>let val V(x,y,z)=L.force a
      in Math.sqrt(value x*value x+value y*value y+value z*value z)end)
        val direction=L.delay(fn()=>let val V(x,y,z)=L.force a
          in V(D.delay(fn()=>value x/value length),D.delay(fn()=>value y/value length),
               D.delay(fn()=>value z/value length))end)
    in(direction,length)end
  fun unit a=L.delay(fn()=>L.force(#1(norm a)))
  val epsilon=1.0E~6
  val infinity=1.0E20
  val zero=vector(0.0,0.0,0.0)
  val white=vector(1.0,1.0,1.0)
  val background=vector(0.078,0.361,0.753)
  val lookfrom=vector(2.1,1.3,1.7)
  val lookat=zero
  val vup=vector(0.0,0.0,1.0)
  fun isZero a=let val V(x,y,z)=L.force a
    in value x<epsilon andalso value y<epsilon andalso value z<epsilon end
  fun vectorSurface pick fallback ss=L.delay(fn()=>
    let fun find []=fallback|find(s::rest)=case pick s of SOME v=>v|NONE=>find rest
    in L.force(find ss)end)
  fun scalarSurface pick fallback ss=D.delay(fn()=>
    let fun find []=fallback|find(s::rest)=case pick s of SOME n=>value n|NONE=>find rest
    in find ss end)
  fun ambient ss=vectorSurface(fn Ambient x=>SOME x|_=>NONE)zero ss
  fun diffuse ss=vectorSurface(fn Diffuse x=>SOME x|_=>NONE)zero ss
  fun specular ss=vectorSurface(fn Specular x=>SOME x|_=>NONE)zero ss
  fun body ss=vectorSurface(fn Body x=>SOME x|_=>NONE)white ss
  fun specpow ss=scalarSurface(fn Specpow x=>SOME x|_=>NONE)8.0 ss
  fun reflect ss=scalarSurface(fn Reflect x=>SOME x|_=>NONE)0.0 ss
  fun transmit ss=scalarSurface(fn Transmit x=>SOME x|_=>NONE)0.0 ss
  fun refract ss=scalarSurface(fn Refract x=>SOME x|_=>NONE)1.0 ss
  fun surface(Sphere(_,_,ss))=ss
  val standard=[Ambient(vector(0.035,0.0325,0.025)),Diffuse(vector(0.5,0.45,0.35)),
    Specular(vector(0.8,0.8,0.8)),Specpow(number 3.0),Reflect(number 0.5)]
  fun ball(x,y,z,r)=Sphere(vector(x,y,z),number r,standard)
  val world=List.map ball[
    (0.0,0.0,0.0,0.5),(0.272166,0.272166,0.544331,0.166667),
    (0.643951,0.172546,0.0,0.166667),(0.172546,0.643951,0.0,0.166667),
    (~0.371785,0.0996195,0.544331,0.166667),(~0.471405,0.471405,0.0,0.166667),
    (~0.643951,~0.172546,0.0,0.166667),(0.0996195,~0.371785,0.544331,0.166667),
    (~0.172546,~0.643951,0.0,0.166667),(0.471405,~0.471405,0.0,0.166667)]
  val lightColor=vector(0.288675,0.288675,0.288675)
  val lights=[Point(vector(4.0,3.0,2.0),lightColor),Point(vector(1.0,~4.0,4.0),lightColor),
    Point(vector(~3.0,1.0,5.0),lightColor)]
  fun intersect pos dir(Sphere(center,radius,_))=L.delay(fn()=>
    let val m=sub pos center val m2=dot m m val bm=dot m dir
        val disc=D.delay(fn()=>value bm*value bm-value m2+value radius*value radius)
    in if value disc<0.0 then(false,number 0.0)
       else let val root=L.delay(fn()=>Math.sqrt(value disc))
                val lo=D.delay(fn()=> ~(value bm)-L.force root)
                val hi=D.delay(fn()=> ~(value bm)+L.force root)
            in if value lo<0.0 then if value hi<0.0 then(false,number 0.0)
               else(true,hi)else(true,lo)end end)
  fun trace spheres pos dir=L.delay(fn()=>
    let fun distances []=S.empty()
          |distances(sp::rest)=L.delay(fn()=>
            let val(hit,distance)=L.force(intersect pos dir sp)
            in if hit then S.Cons(L.delay(fn()=>(distance,sp)),distances rest)
               else L.force(distances rest)end)
        val ds=distances spheres
        fun choose xs base=L.delay(fn()=>case L.force xs of S.Nil=>L.force base
          |S.Cons(p,rest)=>let val(a,sa)=L.force p val(b,sb)=L.force(choose rest base)
              in if value a<value b then(a,sa)else(b,sb)end)
    in case L.force ds of S.Nil=>(false,number infinity,L.delay(fn()=>hd spheres))
       |S.Cons(first,rest)=>
         let val best=choose rest first
         in(true,D.delay(fn()=>value(#1(L.force best))),L.delay(fn()=> #2(L.force best)))end end)
  fun normal pos(Sphere(center,radius,_))=scale(sub pos center)(D.delay(fn()=>1.0/value radius))
  fun lightColour(Directional(_,color))=color|lightColour(Point(_,color))=color
  fun lightDirection(Directional(dir,_))_=L.delay(fn()=>(unit dir,number infinity))
    |lightDirection(Point(pos,_))point=L.delay(fn()=>norm(sub pos point))
  fun shadow pos dir color=L.delay(fn()=>
    let val(hit,_,_)=L.force(trace world(add pos(scale dir(number epsilon)))dir)
    in(hit,color)end)
  fun refractRay index olddir innorm=L.delay(fn()=>
    let val dotp=D.delay(fn()=> ~(value(dot olddir innorm)))
        val parameters=L.delay(fn()=>if value dotp<0.0
          then(scale innorm(number ~1.0),D.delay(fn()=> ~(value dotp)),D.delay(fn()=>1.0/value index))
          else(innorm,dotp,index))
        fun nr()= #3(L.force parameters)fun k()= #2(L.force parameters)
        val disc=D.delay(fn()=>1.0-value(nr())*value(nr())*(1.0-value(k())*value(k())))
    in if value disc<0.0 then(true,zero)
       else let val(n,k,nr)=L.force parameters
                val t=D.delay(fn()=>value nr*value k-Math.sqrt(value disc))
            in(false,add(scale n t)(scale olddir nr))end end)
  fun vectorSum values=L.delay(fn()=>case L.force values of S.Nil=>L.force zero
    |S.Cons(v,rest)=>L.force(add(L.force v)(vectorSum rest)))
  fun lightRay light pos normal reflection ss=L.delay(fn()=>
    let val direction=L.delay(fn()=> #1(L.force(lightDirection light pos)))
        val cosangle=dot(L.delay(fn()=>L.force(L.force direction)))normal
        val result=shadow pos(L.delay(fn()=>L.force(L.force direction)))(lightColour light)
    in if #1(L.force result)then L.force zero
       else let val diff=diffuse ss val power=specpow ss
                val ld=L.force direction val color= #2(L.force result)
            in if value cosangle<=0.0 then
                 let val cosalpha=D.delay(fn()=> ~(value(dot reflection ld)))
                     val diffuseColor=mult(scale diff(D.delay(fn()=> ~(value cosangle))))color
                     val specularColor=L.delay(fn()=>if value cosalpha<=0.0 then L.force zero
                       else L.force(mult(scale(body ss)(D.delay(fn()=>Math.pow(value cosalpha,value power))))color))
                 in L.force(add diffuseColor specularColor)end
               else let val cosalpha=dot reflection ld
                        val diffuseColor=mult(scale diff cosangle)color
                        val specularColor=L.delay(fn()=>if value cosalpha<=0.0 then L.force zero
                          else L.force(mult(scale(specular ss)(D.delay(fn()=>Math.pow(value cosalpha,value power))))color))
                    in L.force(add diffuseColor specularColor)end end end)
  fun shade lights sphere lookpos dir distance contribution=L.delay(fn()=>
    let val hitpos=add lookpos(scale dir distance)val ss=surface sphere
        val ambientColor=mult white(ambient ss)
        val n=normal hitpos sphere
        val reflection=add dir(scale n(D.delay(fn()=> ~2.0*value(dot dir n))))
        val diff=vectorSum(S.map(fn l=>lightRay l hitpos n reflection ss)(S.fromList lights))
        val simple=add ambientColor diff
        val transmitted=transmit ss
        val intensity=scale(body ss)transmitted
        val transmittedResult=L.delay(fn()=>if value transmitted<epsilon then(false,simple)
          else L.force(transmitRay lights simple hitpos dir(refract ss)intensity contribution n))
        val reflectionBase=scale(specular ss)(reflect ss)
        val reflectivity=L.delay(fn()=>L.force(if #1(L.force transmittedResult)
          then add intensity reflectionBase else reflectionBase))
    in if isZero reflectivity then L.force(#2(L.force transmittedResult))
       else L.force(reflectRay hitpos reflection lights reflectivity contribution
         (L.delay(fn()=>L.force(#2(L.force transmittedResult)))))end)
  and transmitRay lights color pos dir index intensity contribution n=L.delay(fn()=>
    let val newcontrib=mult intensity contribution
    in if isZero newcontrib then(false,color)
       else let val direction=L.delay(fn()=>L.force(#2(L.force(refractRay index dir n))))
                val near=add pos(scale direction(number epsilon))
                val result=trace world near direction
                val newcolor=L.delay(fn()=>let val(hit,distance,sphere)=L.force result
                  in if hit then L.force(shade lights(L.force sphere)near direction distance newcontrib)
                     else L.force background end)
            in(false,add(mult newcolor intensity)color)end end)
  and reflectRay pos direction lights intensity contribution color=L.delay(fn()=>
    let val newcontrib=mult intensity contribution
    in if isZero newcontrib then L.force color
       else let val near=add pos(scale direction(number epsilon))
                val result=trace world near direction
                val newcolor=L.delay(fn()=>let val(hit,distance,sphere)=L.force result
                  in if hit then L.force(shade lights(L.force sphere)near direction distance newcontrib)
                     else L.force background end)
            in L.force(add color(mult newcolor intensity))end end)
  fun camera from at up field size=
    let val initial=sub at from val normalized=L.delay(fn()=>norm initial)
        val direction=L.delay(fn()=>L.force(#1(L.force normalized)))
        val distance=D.delay(fn()=>value(#2(L.force normalized)))
        val i=unit(cross direction up)val j=unit(cross i direction)
        val magnitude=D.delay(fn()=>2.0*value distance*Math.tan((field/2.0)*Math.pi/180.0)/size)
        val x=scale i magnitude val y=scale j magnitude
        val first=sub initial(add(scale x(number(0.5*size)))(scale y(number(0.5*size))))
    in(first,x,y)end
  fun pixel spheres lights i j first x y=L.delay(fn()=>
    let val direction=unit(add(add first(scale x(number i)))(scale y(number j)))
        val result=trace spheres lookfrom direction
        val(hit,distance,sphere)=L.force result
    in if hit then L.force(shade lights(L.force sphere)lookfrom direction distance white)
       else L.force background end)
  fun indices size=
    let fun loop i=L.delay(fn()=>if i>=size then S.Nil else
          S.Cons(L.delay(fn()=>i),loop(i+1)))
    in loop 0 end
  fun ray size=
    let val parameters=L.delay(fn()=>camera lookfrom lookat vup 45.0(Real.fromInt size))
    in S.concatMap(fn i=>S.map(fn j=>
      let val color=L.delay(fn()=>let val(first,x,y)=L.force parameters
        in L.force(pixel world lights(Real.fromInt i)(Real.fromInt j)first x y)end)
      in(i,j,color)end)(indices size))(indices size)end
  fun components v=let val V(r,g,b)=L.force v in(value r,value g,value b)end
end
