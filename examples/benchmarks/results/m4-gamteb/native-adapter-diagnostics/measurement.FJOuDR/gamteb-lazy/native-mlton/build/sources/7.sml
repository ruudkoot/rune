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
functor BenchGamtebFn(D:BENCH_SUSPEND) =
struct
  structure M=BenchGamtebMathFn(D)
  structure T=BenchGamtebTablesFn(D)
  structure L=BenchLazy
  structure S=BenchStream
  open M
  type probability=(number*number*number*number)L.delay
  datatype particle=Part of point L.delay*point L.delay*number*number*int L.delay*int*number
  type result=(int*int L.delay)*number
  type stat=int*number
  type outcome=(result S.stream*stat S.stream)L.delay
  fun pointValue(a,b,c)=(value a,value b,value c)
  fun particle pos dir weight energy index cell seed=
    let val _=D.delay(fn()=>
      (pointValue(L.force pos);pointValue(L.force dir);value weight;value energy;L.force index;value seed;()))
    in Part(pos,dir,weight,energy,index,cell,seed)end
  fun xsect energy=
    let val logE=eval(fn()=>Math.ln(value energy))
        val index=L.delay(fn()=>
          let fun find i=if i<35 andalso value logE>T.at T.erg i then find(i+1)else i
          in find 1 end)
        val interval=L.delay(fn()=>Int.max(2,L.force index))
        val fraction=eval(fn()=>let val i=L.force interval in
          (value logE-T.at T.erg(i-1))/(T.at T.erg i-T.at T.erg(i-1))end)
        fun interpolate array=eval(fn()=>let val i=L.force interval in
          Math.exp(T.at array(i-1)+value fraction*(T.at array i-T.at array(i-1)))end)
        val comp=interpolate T.xc val pair=interpolate T.xp val phot=interpolate T.xpe
        val total=eval(fn()=>value comp+value pair+value phot)
    in(index,L.delay(fn()=>(comp,pair,phot,total)))end
  fun lazyXsect energy=
    let val shared=L.delay(fn()=>xsect energy)
    in(L.delay(fn()=>L.force(#1(L.force shared))),
       L.delay(fn()=>L.force(#2(L.force shared))))end
  fun first(outcome:outcome)=L.delay(fn()=>L.force(#1(L.force outcome)))
  fun second(outcome:outcome)=L.delay(fn()=>L.force(#2(L.force outcome)))
  fun oneStat id=S.singleton(id,literal 1.0)
  fun photo(Part(pos,dir,weight,energy,index,cell,seed))prob=L.delay(fn()=>
    let val(_,_,phot,total)=L.force prob
        val(next,r2)=random seed val(roulette,_)=random r2
        val reduced=eval(fn()=>value weight*(1.0-value phot/value total))
        val restored=eval(fn()=>0.5/Real.fromInt cell)
        val absorb=eval(fn()=>value weight-value reduced)
        val killed=if value reduced>0.25 then false
          else value reduced*Real.fromInt cell<value roulette*0.5
        val finalWeight=if value reduced>0.25 orelse killed then reduced else restored
    in(particle pos dir finalWeight energy index cell next,absorb,killed)end)
  fun compton(Part(pos,dir,weight,energy,index,cell,seed))=L.delay(fn()=>
    let val(next,r2)=random seed val(r3,r4)=random r2
        val energyIn=eval(fn()=>1.956917*value energy)
        val energyOut=klein energyIn r3
        val angle=eval(fn()=>1.0+1.0/value energyIn-1.0/value energyOut)
        val newEnergy=eval(fn()=>0.511008*value energyOut)
        val(newIndex,newProb)=lazyXsect newEnergy
        val killed=value newEnergy<=0.001
        val newDir=if killed then dir else L.delay(fn()=>rotate(L.force dir)angle r4)
    in(particle pos newDir weight newEnergy newIndex cell next,newProb,killed)end)
  fun pairProduction(Part(pos,dir,weight,energy,index,cell,seed))=L.delay(fn()=>
    let val(next,r2)=random seed val(r3,_)=random r2
        val newEnergy=literal 0.511008
        val(newIndex,newProb)=lazyXsect newEnergy
        val newWeight=eval(fn()=>2.0*value weight)
        val killed=value newEnergy<=0.001
        val newDir=if killed then dir else L.delay(fn()=>isotropic r3)
    in(particle pos newDir newWeight newEnergy newIndex cell next,newProb,killed)end)
  fun roulette(Part(pos,dir,weight,energy,index,cell,seed))=L.delay(fn()=>
    let val(r1,r2)=random seed val(next,_)=random r2
    in if value r1<0.5 then
         (particle pos dir(eval(fn()=>2.0*value weight))energy index 1 next,
          S.fromList[(6,literal 1.0),(12,weight)],false)
       else(particle pos dir(literal 0.0)energy index 1 next,
          S.fromList[(6,literal 1.0),(10,literal 1.0),(11,weight)],true)end)
  fun split(Part(pos,dir,weight,energy,index,cell,seed))=
    let val(a,b)=random seed
    in(particle pos dir(eval(fn()=>0.5*value weight))energy index 2 a,
       particle pos dir(eval(fn()=>0.5*value weight))energy index 2 b)end
  fun translate pos dir dist=L.delay(fn()=>
    let val(x,y,z)=L.force pos val(u,v,w)=L.force dir
    in(eval(fn()=>value x+value u*value dist),
       eval(fn()=>value y+value v*value dist),
       eval(fn()=>value z+value w*value dist))end)
  fun transport(p as Part(pos,dir,weight,energy,index,cell,seed))prob:outcome=L.delay(fn()=>
    let val(r,r1)=random seed
        val(comp,pair,phot,total)=L.force prob
        val(surfaceDistance,surface)=distance(L.force pos)(L.force dir)
        val collisionDistance=eval(fn()=> ~(Math.ln(value r)/value total))
        val collisionFirst=value collisionDistance<value surfaceDistance
        val pos'=translate pos dir(if collisionFirst then collisionDistance else surfaceDistance)
        val p'=particle pos' dir weight energy index cell seed
        val task=if collisionFirst then
             collision p' prob(D.delay(fn()=>value r1<value comp/(value total-value phot)))
           else noCollision p' prob surface
    in(first task,S.append(oneStat(if collisionFirst then 8 else 9))(second task))end)
  and noCollision(p as Part(pos,dir,weight,energy,index,cell,seed))prob surface:outcome=L.delay(fn()=>
    case surface of
      1=>(S.singleton((1,index),weight),oneStat 3)
    |2=>(S.singleton((2,index),weight),oneStat 1)
    |4=>(S.singleton((3,index),weight),oneStat 2)
    |3=>if cell=1 then
         let val(a,b)=split p val firstTask=transport a prob val secondTask=transport b prob
         in(S.append(first firstTask)(first secondTask),
            S.append(oneStat 7)(S.append(second firstTask)(second secondTask)))end
       else let val(p',stats,killed)=L.force(roulette p)
            in if killed then(S.empty(),stats)
               else let val task=transport p' prob
                    in(first task,S.append(second task)stats)end end
    |_=>raise Match)
  and collision p prob doCompton:outcome=L.delay(fn()=>
    let val(p',absorb,killed)=L.force(photo p prob)
    in if killed then(S.empty(),oneStat 5)
       else let val(next,prob',energyCut)=
                   L.force(if D.force doCompton then compton p' else pairProduction p')
            in if energyCut then(S.empty(),oneStat 4)
               else L.force(transport next prob')end end)
  fun sources seed count energy:outcome=L.delay(fn()=>
    if count<=1 then
      let val(index,prob)=lazyXsect energy val(next,_)=random seed
          val pos=L.delay(fn()=>(literal 0.0,literal 0.0,literal 0.0))
          val dir=L.delay(fn()=>(literal 0.0,literal 1.0,literal 0.0))
      in L.force(transport(particle pos dir(literal 1.0)energy index 1 next)prob)end
    else let val left=count div 2 val right=count-left
             val(a,b)=random seed
             val firstTask=sources a left energy val secondTask=sources b right energy
         in(S.append(first firstTask)(first secondTask),S.append(second firstTask)(second secondTask))end)
  fun run count=sources(literal 0.5)count(literal 6.0)
  fun resultValue((kind,index),weight)=(kind,L.force index,value weight)
  fun statValue(id,amount)=(id,value amount)
  fun tableHeads()=[T.at T.erg 1,T.at T.xc 1,T.at T.xp 1,T.at T.xpe 1]
end
