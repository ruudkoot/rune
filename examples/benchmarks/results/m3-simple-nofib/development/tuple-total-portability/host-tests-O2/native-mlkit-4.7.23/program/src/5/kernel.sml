(* nofib spectral/simple: immutable boxed arrays, binary64 arithmetic. *)
functor BenchSimpleNofibFn(val strict:bool val gridMax:int)=
struct
 structure A=BenchSimpleArraysFn(val strict=strict)
 structure L=BenchLazy
 type array=real A.grid
 type vector=real Vector.vector
 type state=(array*array)*(array*array)*array*array*array*array*array*array*array*real L.delay*real L.delay
 fun delay f=L.delay f
 fun force x=L.force x
 fun sq(x:real)=x*x
 fun pow(x:real,n)=
   if n=0 then 1.0 else if n=1 then x
   else let val y=pow(x,n div 2)val z=y*y in if n mod 2=0 then z else z*x end
 fun range a b=A.range a b
 fun coords ks ls=List.concat(List.map(fn k=>List.map(fn l=>(k,l))ls)ks)
 fun north((k,l):A.zone)=(k-1,l)
 fun south((k,l):A.zone)=(k+1,l)
 fun east((k,l):A.zone)=(k,l+1)
 fun west((k,l):A.zone)=(k,l-1)
 val northeast=north o east
 val northwest=north o west
 val southeast=south o east
 val southwest=south o west
 val farnorth=north o north
 val farsouth=south o south
 val fareast=east o east
 val farwest=west o west
 fun zoneA z=z
 val zoneB=south
 val zoneC=southeast
 val zoneD=east
 val cornerNE=north
 val cornerNW=northwest
 fun cornerSE z=z
 val cornerSW=west
 val kmin=2 val lmin=2 val kmax=gridMax val lmax=gridMax
 val allNodes=((kmin-1,lmin-1),(kmax+1,lmax+1))
 val interiorNodes=((kmin,lmin),(kmax,lmax))
 val allZones=((kmin,lmin),(kmax+1,lmax+1))
 val interiorZones=((kmin+1,lmin+1),(kmax,lmax))
 val nodes=A.positions interiorNodes
 val zones=A.positions interiorZones
 val northZones=coords[kmin](range lmin(lmax+1))
 val southZones=coords[kmax+1](range(lmin+1)lmax)
 val eastZones=coords(range(kmin+1)(kmax+1))[lmax+1]
 val westZones=coords(range(kmin+1)(kmax+1))[lmin]
 fun zoneDirection(k,l)=
   if k=kmin then south
   else if k=kmax+1 andalso l>lmin andalso l<=lmax then north
   else if l=lmax+1 then west else east
 fun isInterior(k,l)=k>kmin andalso k<=kmax andalso l>lmin andalso l<=lmax
 val constantHeat=0.0 val dtMaximum=0.01 val specificHeat=0.1
 val pi=3.141592653589793
 val pCoeffs=A.make((0,0),(2,2))(fn(i,j)=>if i=1 andalso j=1 then 0.06698 else 0.0)
 val eCoeffs=A.make((0,0),(2,2))(fn(i,j)=>if i=0 andalso j=1 then 0.1 else 0.0)
 val pPoly=A.make((1,1),(4,5))(fn _=>pCoeffs)
 val ePoly=A.make((1,1),(4,5))(fn _=>eCoeffs)
 val rhoTable=Vector.fromList[0.0,1.0,100.0]
 val thetaTable=Vector.fromList[0.0,3.0,300.0,3000.0]
 val pbb=Vector.fromList[0.0,6.0,0.0,0.0]
 val pb=Vector.fromList[1.0,0.0,0.0,1.0]
 val qb=pb
 fun vectorSub table i=Vector.sub(table,i-1)
 fun boundaryTable maximum=
   A.associations((2,2),(maximum+1,maximum+1))(fn()=>
     let val one=L.delay(fn()=>1)val two=L.delay(fn()=>2)val four=L.delay(fn()=>4)
         fun assign positions value=List.map(fn position=>(position,value))positions
     in assign(coords[2](range 3 maximum))one
       @assign(coords[maximum+1](range 3 maximum))two
       @assign(coords(range 3 maximum)[2])one
       @assign(coords(range 3 maximum)[maximum+1])one
       @assign[(2,2),(2,maximum+1),(maximum+1,2),(maximum+1,maximum+1)]four end)
 val nbc=boundaryTable gridMax
 fun boundaryCode zone=A.sub nbc zone
 fun sum values=A.foldl(fn(a:real,b)=>a+b)(L.delay(fn()=>0.0))values
 fun sumMap f positions=sum(A.mapList f positions)
 fun minimum(a:real,b)=if a<=b then a else b
 fun maximum(a:real,b)=if a<=b then b else a
 fun minList values=A.foldl minimum(L.delay(fn()=>A.head values))values
 fun maxList values=A.foldl maximum(L.delay(fn()=>A.head values))values
 fun polynomial g degree rhoValue thetaValue=
   let fun search table value=
         let val high=Vector.length table
             fun down i=if value>Vector.sub(table,i-2)then i else down(i-1)
         in if value>Vector.sub(table,high-1)then high+1
            else if value<=Vector.sub(table,0)then 1 else down high end
       val a=L.delay(fn()=>A.sub g(search rhoTable rhoValue,search thetaTable thetaValue))
   in sumMap(fn(i,j)=>(A.sub(force a)(i,j)*pow(rhoValue,i))*pow(thetaValue,j))
        (coords(range 0 degree)(range 0 degree))end
 fun zonalPressure rho theta=polynomial pPoly 2 rho theta
 fun zonalEnergy rho theta=polynomial ePoly 2 rho theta
 fun newton f x=
   let fun loop x fx=
         if fx>0.000001 then
           let val fxdx=f(x+0.000001)val denom=fxdx-fx
           in if denom<0.000001 then loop x 0.000001
              else loop(x-(fx*0.000001)/denom)fxdx end
         else x
   in loop x(f x)end
 fun boundaryPosition(rx,zx,ry,zy,ra,za)=
   let val rax=ra-rx val zax=za-zx val ryx=ry-rx val zyx=zy-zx
       val omega=(2.0*(rax*ryx+zax*zyx))/(sq ryx+sq zyx)
   in(delay(fn()=>(rx-rax)+omega*ryx),delay(fn()=>(zx-zax)+omega*zyx))end
 fun positionMatrix interior=
   A.recursivePair allNodes(fn(r,z)=>fn node as(k,l)=>
     if k>=kmin andalso k<=kmax andalso l>=lmin andalso l<=lmax
     then interior node
     else let
       val(xdir,ydir,adir)=
         if k=kmin-1 andalso l>=lmin andalso l<lmax then(south,southeast,farsouth)
         else if k=kmax+1 andalso l>=lmin andalso l<lmax then(north,northeast,farnorth)
         else if l=lmax+1 andalso k>=kmin andalso k<kmax then(west,southwest,farwest)
         else if l=lmin-1 andalso k>=kmin andalso k<kmax then(east,southeast,fareast)
         else if k=kmin-1 andalso l=lmax+1 then(southwest,west,farwest)
         else if k=kmax+1 andalso l=lmax+1 then(northwest,west,farwest)
         else if k=kmin-1 andalso l=lmin-1 then(southeast,south,farsouth)
         else if k=kmax+1 andalso l=lmin-1 then(northeast,east,fareast)
         else if k=kmin-1 andalso l=lmax then(south,southwest,farsouth)
         else if k=kmax+1 andalso l=lmax then(north,northwest,farnorth)
         else if k=kmax andalso l=lmax+1 then(west,northwest,farwest)
         else if k=kmax andalso l=lmin-1 then(east,northeast,fareast)
         else raise Fail"position coverage"
       in boundaryPosition(A.sub r(xdir node),A.sub z(xdir node),
            A.sub r(ydir node),A.sub z(ydir node),A.sub r(adir node),A.sub z(adir node))end)
 fun zoneAreaVolume(r,z)zone=
   let val rsw=A.sub r(cornerSW zone)val zsw=A.sub z(cornerSW zone)
       val rse=A.sub r(cornerSE zone)val zse=A.sub z(cornerSE zone)
       val rne=A.sub r(cornerNE zone)val zne=A.sub z(cornerNE zone)
       val rnw=A.sub r(cornerNW zone)val znw=A.sub z(cornerNW zone)
       val a1=(rse*(zne-zsw)+rsw*(zse-zne))+rne*(zsw-zse)
       val a2=(rnw*(zsw-zne)+rne*(znw-zsw))+rsw*(zne-znw)
   in(delay(fn()=>(a1+a2)/2.0),
      delay(fn()=>((a1*((rsw+rse)+rne))/3.0+(a2*((rsw+rne)+rnw))/3.0)*pi))end
 fun lineIntegral(p:array)(z:array)(node:A.zone):real=
   (((A.sub p(zoneA node)*(A.sub z(west node)-A.sub z(north node))
      +A.sub p(zoneB node)*(A.sub z(south node)-A.sub z(west node)))
      +A.sub p(zoneC node)*(A.sub z(east node)-A.sub z(south node)))
      +A.sub p(zoneD node)*(A.sub z(north node)-A.sub z(east node)))
 fun makePressure rho theta=
   A.recursive allZones(fn p=>fn zone=>
     if isInterior zone then zonalPressure(A.sub rho zone)(A.sub theta zone)
     else let val code=boundaryCode zone
          in vectorSub pbb code+vectorSub pb code*A.sub p(zoneDirection zone zone)end)
 fun makeEnergy rho theta=
   A.recursive allZones(fn e=>fn zone=>
     if isInterior zone then zonalEnergy(A.sub rho zone)(A.sub theta zone)
     else A.sub e(zoneDirection zone zone))
 fun makeVelocity(u,w)(r,z)p q alpha rho dt=
   A.pair interiorNodes(fn node=>
     let fun mass zone=A.sub rho zone*A.sub alpha zone
         val d=0.5*(((mass(zoneA node)+mass(zoneB node))+mass(zoneC node))+mass(zoneD node))
     in(delay(fn()=>A.sub u node+dt*((~(lineIntegral p z node)-lineIntegral q z node)/d)),
        delay(fn()=>A.sub w node+dt*((lineIntegral p r node+lineIntegral q r node)/d)))end)
 fun makePosition(r,z)dt(u,w)=
   positionMatrix(fn node=>(delay(fn()=>A.sub r node+dt*A.sub u node),
                           delay(fn()=>A.sub z node+dt*A.sub w node)))
 fun makeAreaDensity rho s x=
   A.recursiveTriple allZones(fn(alpha',s',rho')=>fn zone=>
     if isInterior zone then
       let val(area,vol)=zoneAreaVolume x zone
       in(area,vol,delay(fn()=>(A.sub rho zone*A.sub s zone)/force vol))end
     else let val neighbor=zoneDirection zone zone
          in(delay(fn()=>A.sub alpha' neighbor),delay(fn()=>A.sub s' neighbor),
             delay(fn()=>A.sub rho' neighbor))end)
 fun makeViscosity p(u,w)(r,z)alpha rho=
   A.recursivePair allZones(fn(q,_)=>fn zone=>
     if isInterior zone then
       let fun upper f=0.5*(((A.sub f(cornerSE zone)-A.sub f(cornerNE zone))
                          +A.sub f(cornerSW zone))-A.sub f(cornerNW zone))
           fun lower f=0.5*(((A.sub f(cornerSE zone)-A.sub f(cornerSW zone))
                          +A.sub f(cornerNE zone))-A.sub f(cornerNW zone))
           val ur=delay(fn()=>upper r)val uz=delay(fn()=>upper z)
           val lr=delay(fn()=>lower r)val lz=delay(fn()=>lower z)
           val sound=delay(fn()=>(1.6*A.sub p zone)/A.sub rho zone)
           val upperDisc=delay(fn()=>force ur*lower w-force uz*lower u)
           val lowerDisc=delay(fn()=>upper u*force lz-upper w*force lr)
           val ubar=delay(fn()=>
             (if force upperDisc<0.0 then sq(force upperDisc)/(sq(force ur)+sq(force uz))else 0.0)
             +(if force lowerDisc<0.0 then sq(force lowerDisc)/(sq(force lr)+sq(force lz))else 0.0))
       in(delay(fn()=>A.sub rho zone*((sq 1.22474487/4.0)*force ubar
                          +((0.50/2.0)*force sound)*Math.sqrt(force ubar))),
          delay(fn()=>((0.5*A.sub alpha zone)/force sound)*Math.sqrt(sq(force ur)+sq(force lr))))end
     else(delay(fn()=>A.sub q(zoneDirection zone zone)*vectorSub qb(boundaryCode zone)),
          delay(fn()=>0.0)))
 fun makeTemperature p epsilon rho theta rho' q'=
   A.make allZones(fn zone=>if not(isInterior zone)then constantHeat else
     let val qkl=A.sub q' zone val rhokl=A.sub rho zone
         val tau=1.0/A.sub rho' zone-1.0/rhokl
         val e0=A.sub epsilon zone val p0=A.sub p zone val t0=A.sub theta zone
         val e1=e0-(p0+qkl)*tau
         val t1=newton(fn t=>e1-zonalEnergy rhokl t)t0
         val p1=zonalPressure rhokl t1
         val e2=e0-(p1+qkl)*tau
     in newton(fn t=>e2-zonalEnergy rhokl t)t1 end)
 fun makeCc alpha theta=
   A.recursive allZones(fn cc=>fn zone=>if isInterior zone
     then(0.0001*Math.pow(A.sub theta zone,2.5))/A.sub alpha zone
     else A.sub cc(zoneDirection zone zone))
 fun makeSigma dt rho alpha=
   A.make interiorZones(fn zone=>((A.sub rho zone*A.sub alpha zone)*specificHeat)/dt)
 fun makeGamma(r,z)cc succeeding adjacent=
   A.make allZones(fn zone=>if not(isInterior zone)then 0.0 else
     let val r1=A.sub r(cornerSE zone)val z1=A.sub z(cornerSE zone)
         val r2=A.sub r(cornerSE(adjacent zone))val z2=A.sub z(cornerSE(adjacent zone))
         val c1=A.sub cc zone val c2=A.sub cc(succeeding zone)
         val cross=(0.5*(r1+r2))*(sq(r1-r2)+sq(z1-z2))
     in cross*(((2.0*c1)*c2)/(c1+c2))end)
 fun makeAb theta sigma gamma preceding=
   A.recursivePair allZones(fn(a,b)=>fn zone=>
     if not(isInterior zone)then(delay(fn()=>0.0),delay(fn()=>A.sub theta zone))
     else let val previous=preceding zone
              val denom=(A.sub sigma zone+A.sub gamma zone)
                        +A.sub gamma previous*(1.0-A.sub a previous)
              val n1=A.sub gamma zone
              val n2=A.sub gamma previous*A.sub b previous
                       +A.sub sigma zone*A.sub theta zone
              val x=n1/denom val y=n2/denom
              val _=ignore(x+y)
          in(delay(fn()=>x),delay(fn()=>y))end)
 fun makeTheta a b succeeding=
   A.recursive allZones(fn theta=>fn zone=>if isInterior zone
     then A.sub a zone*A.sub theta(succeeding zone)+A.sub b zone else constantHeat)
 fun heatConduction theta dt x alpha rho=
   let val sigma=L.delay(fn()=>makeSigma dt rho alpha)
       val cc=L.delay(fn()=>makeCc alpha theta)
       val gk=L.delay(fn()=>makeGamma x(force cc)north east)
       val abk=L.delay(fn()=>makeAb theta(force sigma)(force gk)north)
       val tk=L.delay(fn()=>let val(a,b)=force abk in makeTheta a b south end)
       val gl=L.delay(fn()=>makeGamma x(force cc)west south)
       val abl=L.delay(fn()=>makeAb(force tk)(force sigma)(force gl)west)
       val tl=L.delay(fn()=>let val(a,b)=force abl in makeTheta a b east end)
   in(tl,gk,gl)end
 fun energyError(u,w)(r,z)p q epsilon theta rho alpha gk gl dt=
   let fun mass zone=A.sub rho zone*A.sub alpha zone
       val internal=sum(A.mapList(fn zone=>A.sub epsilon zone*mass zone)zones)
       fun kinetic node=
         let val average=0.25*(((mass(zoneA node)+mass(zoneB node))+mass(zoneC node))+mass(zoneD node))
         in(0.5*average)*(sq(A.sub u node)+sq(A.sub w node))end
       val kineticEnergy=sum(A.mapList kinetic nodes)
       fun work(node1,node2)=
         let val r1=A.sub r node1 val r2=A.sub r node2
             val z1=A.sub z node1 val z2=A.sub z node2
             (* Original uses pressure for u1/u2 and z for w1/w2. *)
             val u1=A.sub p node1 val u2=A.sub p node2
             val w1=A.sub z node1 val w2=A.sub z node2
             val p1=A.sub p node1 val p2=A.sub p node2
             val q1=A.sub q node1 val q2=A.sub q node2
             val f=0.5*(((p1+p2)+q1)+q2)
             val radius=0.5*(r1+r2)
             val area=0.5*((r1-r2)*(u1-u2)-(z1-z2)*(w1-w2))
         in((f*radius)*area)*dt end
       fun segments dir zs=List.map(fn z=>(dir z,z))zs
       val w1=sum(A.mapList work(segments west(coords[kmin](range(lmin+1)lmax))))
       val w2=sum(A.mapList work(segments west(coords[kmax](range(lmin+1)lmax))))
       val w3=sum(A.mapList work(segments south(coords(range(kmin+1)kmax)[lmax])))
       val w4=sum(A.mapList work(segments south(coords(range(kmin+1)kmax)[lmin+1])))
       val boundaryWork=((w1+w2)+w3)+w4
       fun flow g(zone1,zone2)=(dt*A.sub g zone1)*(A.sub theta zone1-A.sub theta zone2)
       val h1=sum(A.mapList(flow gk)(segments north(coords[kmin+1](range(lmin+1)lmax))))
       val h2=sum(A.mapList(flow gk)(segments south(coords[kmax](range(lmin+2)(lmax-1)))))
       val h3=sum(A.mapList(flow gl)(segments east(coords(range(kmin+2)kmax)[lmax])))
       val h4=sum(A.mapList(flow gl)(segments west(coords(range(kmin+2)kmax)[lmin+1])))
   in((internal+kineticEnergy)-(((h1+h2)+h3)+h4))-boundaryWork end
 fun timestep d thetaHat theta=
   let val courant=minList(A.mapList(fn zone=>A.sub d zone)zones)
       val conduction=maxList(A.mapList(fn zone=>
         Real.abs(A.sub thetaHat zone-A.sub theta zone)/A.sub thetaHat zone)zones)
   in minimum(dtMaximum,minimum(courant,conduction))end
 fun suspend f=L.delay(fn()=>L.force(f()))
 fun pairSuspend f=
   let val shared=delay f
   in(suspend(fn()=>let val(a,_)=force shared in a end),
      suspend(fn()=>let val(_,b)=force shared in b end))end
 fun tripleSuspend f=
   let val shared=delay f
   in(suspend(fn()=>let val(a,_,_)=force shared in a end),
      suspend(fn()=>let val(_,b,_)=force shared in b end),
      suspend(fn()=>let val(_,_,c)=force shared in c end))end
 fun initial():state=
   let val v=(suspend(fn()=>A.make allNodes(fn _=>0.0)),
              suspend(fn()=>A.make allNodes(fn _=>0.0)))
       val x=pairSuspend(fn()=>positionMatrix(fn(k,l)=>
         let val radius=Real.fromInt((10+k)-kmin)
             val angle=(~0.5+Real.fromInt(l-lmin)/Real.fromInt(lmax-lmin))*pi
         in(delay(fn()=>radius*Math.cos angle),delay(fn()=>radius*Math.sin angle))end))
       val(alpha,s)=pairSuspend(fn()=>
         A.recursivePair allZones(fn(a,b)=>fn zone=>
           if isInterior zone then zoneAreaVolume x zone
           else let val neighbor=zoneDirection zone zone
                in(delay(fn()=>A.sub a neighbor),delay(fn()=>A.sub b neighbor))end))
       val rho=suspend(fn()=>A.make allZones(fn _=>1.4))
       val theta=suspend(fn()=>A.make allZones(fn zone=>if isInterior zone then 10.0 else constantHeat))
       val p=suspend(fn()=>makePressure rho theta)
       val q=suspend(fn()=>A.make allZones(fn _=>0.0))
       val epsilon=suspend(fn()=>makeEnergy rho theta)
   in(v,x,alpha,s,rho,p,q,epsilon,theta,delay(fn()=>0.01),delay(fn()=>0.0))end
 fun next((v,x,alpha,s,rho,p,q,epsilon,theta,dt,_):state):state=
   let val v'=pairSuspend(fn()=>makeVelocity v x p q alpha rho(force dt))
       val x'=pairSuspend(fn()=>makePosition x(force dt)v')
       val(alpha',s',rho')=tripleSuspend(fn()=>makeAreaDensity rho s x')
       val(q',d)=pairSuspend(fn()=>makeViscosity p v' x' alpha' rho')
       val thetaHat=suspend(fn()=>makeTemperature p epsilon rho theta rho' q')
       val heat=delay(fn()=>heatConduction thetaHat(force dt)x' alpha' rho')
       val theta'=suspend(fn()=>force(#1(force heat)))
       val gk=suspend(fn()=>force(#2(force heat)))
       val gl=suspend(fn()=>force(#3(force heat)))
       val p'=suspend(fn()=>makePressure rho' theta')
       val epsilon'=suspend(fn()=>makeEnergy rho' theta')
       val c'=delay(fn()=>energyError v' x' p' q' epsilon' theta' rho' alpha' gk gl(force dt))
       val dt'=delay(fn()=>timestep d thetaHat theta')
   in(v',x',alpha',s',rho',p',q',epsilon',theta',dt',c')end
 fun arrays(((u,v),(r,z),a,s,rho,p,q,e,t,_,_):state)=
   [("u",u),("v",v),("r",r),("z",z),("alpha",a),("s",s),("rho",rho),("p",p),("q",q),("epsilon",e),("theta",t)]
 type totalValues=real L.delay*real L.delay*real L.delay*real L.delay*
   real L.delay*real L.delay*real L.delay*real L.delay*real L.delay*
   real L.delay*real L.delay*real L.delay*real L.delay
 type totals=totalValues L.delay
 fun totals(((u,v),(r,z),alpha,s,rho,p,q,epsilon,theta,dt,err):state):totals=
   L.delay(fn()=>(L.delay(fn()=>A.total u),L.delay(fn()=>A.total v),
     L.delay(fn()=>A.total r),L.delay(fn()=>A.total z),
     L.delay(fn()=>A.total alpha),L.delay(fn()=>A.total s),
     L.delay(fn()=>A.total rho),L.delay(fn()=>A.total p),L.delay(fn()=>A.total q),
     L.delay(fn()=>A.total epsilon),L.delay(fn()=>A.total theta),dt,err))
 fun totalTotal values=
   let val(a,b,c,d,e,f,g,h,i,j,k,l,m)=L.force values
   in (((((((((((force a+force b)+force c)+force d)+force e)+force f)+force g)+force h)
         +force i)+force j)+force k)+force l)+force m end
 fun totalsList values=
   let val(a,b,c,d,e,f,g,h,i,j,k,l,m)=L.force values
   in[a,b,c,d,e,f,g,h,i,j,k,l,m]end
 fun computeRaw count=
   let fun loop state totals n=if n<1 then(totals,state)
         else(ignore(totalTotal totals);
              let val state'=next state in loop state'(totalsOf state')(n-1)end)
       and totalsOf state=totals state
       val state=initial()
   in loop state(totals state)count end
 (* Observation adapter only: the report consumer uses computeRaw and leaves
  * the final thirteen-tuple root unused, as in the source. *)
 fun compute count=let val(values,state)=computeRaw count in(totalsList values,state)end
end
