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
functor BenchPicFn(D:BENCH_SUSPEND) =
struct
  datatype 'a node=Nil|Cons of 'a D.t * 'a node D.t
  datatype point=Point of real D.t * real D.t
  type heap=point node D.t * point node D.t
  datatype mesh=Mesh of int * real D.t Array.array
  datatype pushed=Pushed of real D.t * real D.t * heap
  datatype state=State of real D.t * mesh D.t * heap D.t
  val nCell=16
  val nStep=10
  fun log2 n =
    let fun loop value total=if value>1 then loop(value div 2)(total+1)else total
    in loop n 0 end
  val maxDepth=log2 nCell-1
  val charge=1.0
  val mass=1.0
  val zero=D.delay(fn()=>0.0)
  val three=D.delay(fn()=>3.0)
  val four=D.delay(fn()=>4.0)
  val five=D.delay(fn()=>5.0)
  val six=D.delay(fn()=>6.0)
  fun empty()=D.delay(fn()=>Nil)
  fun range first last=D.delay(fn()=>if first>last then Nil
    else Cons(D.delay(fn()=>first),range(first+1)last))
  fun map f xs=D.delay(fn()=>case D.force xs of Nil=>Nil
    |Cons(x,rest)=>Cons(D.delay(fn()=>f(D.force x)),map f rest))
  fun indices first last=if first>last then[]else first::indices(first+1)last
  fun pairs xs ys=List.concat(List.map(fn i=>List.map(fn j=>(i,j))ys)xs)
  fun makeMesh n generate=D.delay(fn()=>
    let val _=if n>=2 andalso n<=nCell then()else raise Fail "invalid PIC mesh extent"
        val cells=Array.array(n*n,zero)
        val seen=Array.array(n*n,false)
        fun insert((i,j),value)=
          if i<0 orelse i>=n orelse j<0 orelse j>=n then raise Subscript
          else let val index=i*n+j
               in if Array.sub(seen,index)then raise Fail "incorrect result: duplicate PIC mesh cell"
                  else(Array.update(seen,index,true);Array.update(cells,index,value))end
        val _=List.app insert(generate())
        val _=if Array.foldl(fn(written,ok)=>written andalso ok)true seen then()
          else raise Fail "incorrect result: missing PIC mesh cell"
    in Mesh(n,cells)end)
  fun get mesh(i,j)=case D.force mesh of Mesh(n,cells)=>
    if i<0 orelse i>=n orelse j<0 orelse j>=n then raise Subscript
    else D.force(Array.sub(cells,i*n+j))
  fun zeroMesh n=makeMesh n(fn()=>List.map(fn index=>(index,zero))(pairs(indices 0(n-1))(indices 0(n-1))))
  fun applyOpToMesh operator(mesh:mesh D.t)size=
    let val n=size-1 val n1=size-2
        fun at index makeRange=(index,D.delay(fn()=>operator mesh(makeRange())))
    in makeMesh size(fn()=>
      [at(0,0)(fn()=>[n,0,1,n,0,1]),
       at(0,n)(fn()=>[n,0,1,n1,n,0]),
       at(n,0)(fn()=>[n1,n,0,n,0,1]),
       at(n,n)(fn()=>[n1,n,0,n1,n,0])]@
      List.map(fn j=>at(0,j)(fn()=>[n,0,n1,j-1,j,j+1]))(indices 1 n1)@
      List.map(fn j=>at(n,j)(fn()=>[n1,n,0,j-1,j,j+1]))(indices 1 n1)@
      List.map(fn i=>at(i,0)(fn()=>[i-1,i,i+1,n,0,1]))(indices 1 n1)@
      List.map(fn i=>at(i,n)(fn()=>[i-1,i,i+1,n1,n,0]))(indices 1 n1)@
      List.map(fn(i,j)=>at(i,j)(fn()=>[i-1,i,i+1,j-1,j,j+1]))
        (pairs(indices 1 n1)(indices 1 n1)))end
  fun coarseMesh mesh n=
    let val half=n div 2
    in makeMesh half(fn()=>List.map(fn(i,j)=>((i,j),D.delay(fn()=>get mesh(2*i,2*j))))
      (pairs(indices 0(half-1))(indices 0(half-1))))end
  fun fineMesh(unused:mesh D.t)half=
    let val h=half-1 val n=2*half-1 val is=indices 1 h
    in makeMesh(n+1)(fn()=>
      [((0,0),three),((0,n),three),((n,0),three),((n,n),three)]@
      List.map(fn j=>((0,2*j),four))is@
      List.map(fn j=>((0,2*j-1),four))is@
      List.map(fn j=>((n,2*j),four))is@
      List.map(fn j=>((n,2*j-1),four))is@
      List.map(fn i=>((2*i,0),five))is@
      List.map(fn i=>((2*i-1,0),five))is@
      List.map(fn i=>((2*i,n),five))is@
      List.map(fn i=>((2*i-1,n),five))is@
      List.map(fn(i,j)=>((2*i,2*j),six))(pairs is is)@
      List.map(fn(i,j)=>((2*i,2*j-1),six))(pairs is is)@
      List.map(fn(i,j)=>((2*i-1,2*j),six))(pairs is is)@
      List.map(fn(i,j)=>((2*i-1,2*j-1),six))(pairs is is))end
  fun laplacianOp mesh[iLo,i,iHi,jLo,j,jHi]=
    ~(get mesh(iLo,j)+get mesh(i,jHi)+get mesh(i,jLo)+get mesh(iHi,j)-4.0*get mesh(i,j))
    |laplacianOp _ _=raise Match
  fun residual mesh rhs n=
    applyOpToMesh(fn mesh=>fn positions as[_,i,_,_,j,_]=>
      get rhs(i,j)-laplacianOp mesh positions|_=>raise Match)mesh n
  fun relax mesh rhs n=
    applyOpToMesh(fn mesh=>fn[iLo,i,iHi,jLo,j,jHi]=>
      0.25*get rhs(i,j)+0.25*(get mesh(iLo,j)+get mesh(i,jLo)+get mesh(i,jHi)+get mesh(iHi,j))
      |_=>raise Match)mesh n
  fun correct phi coarse n half=
    let val fine=fineMesh coarse half
    in makeMesh n(fn()=>List.map(fn(i,j)=>((i,j),D.delay(fn()=>get phi(i,j)+get fine(i,j))))
      (pairs(indices 0(n-1))(indices 0(n-1))))end
  fun vCycle phi rho n depth=
    let val phiPrime=relax phi rho n
    in if depth=0 then relax phiPrime rho n
       else let val half=n div 2
                val rhoPrime=residual phiPrime rho n
                val coarse=coarseMesh rhoPrime n
                val zeros=zeroMesh half
                val error=D.delay(fn()=>D.force(vCycle zeros coarse half(depth-1)))
            in correct phiPrime error n half end end
  fun potential phi rho depth count=
    if count=0 then phi else potential(vCycle rho phi nCell depth)rho depth(count-1)
  fun genRand seed=
    let val x=31453257.0*seed+271829.0
        val r=x-Real.fromInt((Real.trunc x div 655357)*655357)
    in r/655357.0 end
  fun initParticles count=
    let val size=Real.fromInt nCell val denominator=Real.fromInt(count+1)
        val positions=map(fn i=>
          let val x=D.delay(fn()=>size*genRand(Real.fromInt i/denominator))
              val y=D.delay(fn()=>size*genRand(D.force x))
          in Point(x,y)end)(range 1 count)
        val velocities=map(fn _=>Point(zero,zero))(range 1 count)
    in(positions,velocities)end
  fun chargeDensity(heap:heap D.t)=D.delay(fn()=>
    let val(positions,_)=D.force heap
        val cells=Array.array(nCell*nCell,zero)
        fun add((i,j),value)=
          if i<0 orelse i>=nCell orelse j<0 orelse j>=nCell then raise Subscript
          else let val index=i*nCell+j val old=Array.sub(cells,index)
               in Array.update(cells,index,D.delay(fn()=>D.force old+D.force value))end
        fun particles xs=case D.force xs of Nil=>()
          |Cons(p,rest)=>
            let val Point(x,y)=D.force p
                val i=Real.trunc(D.force x)val j=Real.trunc(D.force y)
                val ip=(i+1)mod nCell val jp=(j+1)mod nCell
                val dx=D.delay(fn()=>D.force x-Real.fromInt i)
                val dy=D.delay(fn()=>D.force y-Real.fromInt j)
                val deposits=[
                  ((i,j),D.delay(fn()=>charge*(1.0-D.force dx)*(1.0-D.force dy))),
                  ((ip,j),D.delay(fn()=>charge*D.force dx*(1.0-D.force dy))),
                  ((i,jp),D.delay(fn()=>charge*(1.0-D.force dx)*D.force dy)),
                  ((ip,jp),D.delay(fn()=>charge*D.force dx*D.force dy))]
                val _=List.app add deposits
            in particles rest end
        val _=particles positions
    in Mesh(nCell,cells)end)
  fun elecField phi=
    let val n=nCell-1
        val ex=makeMesh nCell(fn()=>
          List.map(fn(i,j)=>((i,j),D.delay(fn()=>get phi(i-1,j)-get phi(i,j))))
            (pairs(indices 1 n)(indices 0 n))@
          List.map(fn j=>((0,j),D.delay(fn()=>get phi(n,j)-get phi(0,j))))(indices 0 n))
        val ey=makeMesh nCell(fn()=>
          List.map(fn(i,j)=>((i,j),D.delay(fn()=>get phi(i,j+1)-get phi(i,j))))
            (pairs(indices 0 n)(indices 0(n-1)))@
          List.map(fn i=>((i,n),D.delay(fn()=>get phi(i,0)-get phi(i,n))))(indices 0 n))
    in(ex,ey)end
  fun larger(a:real,b)=if a>b then a else b
  fun wrapped x=if x>=Real.fromInt nCell then x-Real.fromInt nCell
    else if x<0.0 then x+Real.fromInt nCell else x
  fun pushParticle heap(ex,ey)dt maxAcc maxVel=D.delay(fn()=>
    let val(positions,velocities)=D.force heap
    in case(D.force positions,D.force velocities)of
      (Nil,Nil)=>Pushed(maxAcc,maxVel,(empty(),empty()))
    |(Cons(p,ps),Cons(v,vs))=>
      let val Point(x,y)=D.force p val Point(vx,vy)=D.force v
          val i=D.delay(fn()=>Real.trunc(D.force x))
          val j=D.delay(fn()=>Real.trunc(D.force y))
          val ip=D.delay(fn()=>(D.force i+1)mod nCell)
          val jp=D.delay(fn()=>(D.force j+1)mod nCell)
          val dx=D.delay(fn()=>D.force x-Real.fromInt(D.force i))
          val dy=D.delay(fn()=>D.force y-Real.fromInt(D.force j))
          val ax=D.delay(fn()=>(charge/mass)*(get ex(D.force i,D.force j)*(1.0-D.force dy)+get ex(D.force i,D.force jp)*D.force dy))
          val ay=D.delay(fn()=>(charge/mass)*(get ey(D.force i,D.force j)*(1.0-D.force dx)+get ey(D.force ip,D.force j)*D.force dx))
          val tx=D.delay(fn()=>D.force ax*D.force dt+D.force vx)
          val ty=D.delay(fn()=>D.force ay*D.force dt+D.force vy)
          val px=D.delay(fn()=>wrapped(D.force tx*D.force dt+D.force x))
          val py=D.delay(fn()=>wrapped(D.force ty*D.force dt+D.force y))
          val acc=D.delay(fn()=>larger(D.force maxAcc,larger(Real.abs(D.force ax),Real.abs(D.force ay))))
          val vel=D.delay(fn()=>larger(D.force maxVel,larger(Real.abs(D.force tx),Real.abs(D.force ty))))
          val rest=pushParticle(D.delay(fn()=>(ps,vs)))(ex,ey)dt acc vel
          val outp=D.delay(fn()=>Cons(D.delay(fn()=>Point(px,py)),D.delay(fn()=>
            case D.force rest of Pushed(_,_,(ps,_))=>D.force ps)))
          val outv=D.delay(fn()=>Cons(D.delay(fn()=>Point(tx,ty)),D.delay(fn()=>
            case D.force rest of Pushed(_,_,(_,vs))=>D.force vs)))
      in Pushed(D.delay(fn()=>case D.force rest of Pushed(a,_,_)=>D.force a),
                D.delay(fn()=>case D.force rest of Pushed(_,v,_)=>D.force v),(outp,outv))end
    |_=>raise Match end)
  fun timeStep heap phi dt depth step=
    if step=0 then State(dt,phi,heap)
    else let val rho=chargeDensity heap
             val nextPhi=potential phi rho depth 1
             val electric=elecField nextPhi
             val pushed=pushParticle heap electric dt zero zero
             val nextDt=D.delay(fn()=>case D.force pushed of Pushed(acc,vel,_)=>
               let val a=D.force acc val v=D.force vel
               in(Math.sqrt(a*a+2.0*v)-a)/v end)
             val nextHeap=D.delay(fn()=>case D.force pushed of Pushed(_,_,heap)=>heap)
         in timeStep nextHeap nextPhi nextDt((depth+1)mod maxDepth)(step-1)end
  fun runState count steps=
    let val heap=D.delay(fn()=>initParticles count)
        val phi=potential(zeroMesh nCell)(chargeDensity heap)maxDepth 1
    in timeStep heap phi(D.delay(fn()=>0.001))0 steps end
  fun run count=case runState count nStep of State(dt,_,_)=>D.force dt
end
