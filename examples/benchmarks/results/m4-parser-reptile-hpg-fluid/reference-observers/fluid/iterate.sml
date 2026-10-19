 fun simulate(mon,maxIter,iterTolerance,maxJacobi,jacobiTolerance,relax,time)
       elementFactors velocityAssembly pressureAssembly velocitySteer pressureSteer
       boundary pressureFixed factors(initialPressure,initialVelocity)=
   let
     fun iterate n oldP oldU result=
       let
         val rhs1a=L.delay(fn()=>if normalize oldP andalso normalize oldU then
           getRhs1 elementFactors velocityAssembly velocitySteer pressureSteer(retrieve oldP,retrieve oldU)
           else raise Match)
         val u1a=pack normalVelocity(fn()=>addU(retrieve oldU)
           (jacobi 1 elementFactors velocityAssembly velocitySteer boundary(L.force rhs1a)
             (divide(number 2.0)time)maxJacobi jacobiTolerance relax))
         val rhs1b=L.delay(fn()=>if normalize u1a then
           getRhs1 elementFactors velocityAssembly velocitySteer pressureSteer(retrieve oldP,retrieve u1a)
           else raise Match)
         val u1b=pack normalVelocity(fn()=>addU(retrieve oldU)
           (jacobi 1 elementFactors velocityAssembly velocitySteer boundary(L.force rhs1b)
             (divide one time)maxJacobi jacobiTolerance relax))
         val rhs2=pack(normalArray normalReal)(fn()=>if normalize u1b then
           getRhs2 elementFactors pressureAssembly velocitySteer pressureFixed(retrieve u1b)else raise Match)
         val deltaP=pack(normalArray normalReal)(fn()=>if normalize rhs2 then
           choleskyMethod factors(retrieve rhs2)(divide(number 2.0)time)else raise Match)
         val newP=pack(normalArray normalReal)(fn()=>addMat(retrieve oldP)(retrieve deltaP))
         val rhs3=L.delay(fn()=>if normalize deltaP then
           getRhs3 elementFactors velocityAssembly pressureSteer(retrieve deltaP)else raise Match)
         val newU=pack normalVelocity(fn()=>addU(retrieve u1b)
           (jacobi 3 elementFactors velocityAssembly velocitySteer boundary(L.force rhs3)
             (divide(number 2.0)time)maxJacobi jacobiTolerance relax))
         fun difference a b=zipWith sub(A.elements a)(A.elements b)
         val toleranceU=L.delay(fn()=>
           if normalize newU andalso normalize oldU then
             let val(x,y)=retrieve newU val(a,b)=retrieve oldU
             in tolerance(F.append(A.elements x)(A.elements y))
                  (F.append(difference x a)(difference y b))false end else raise Match)
         val toleranceP=L.delay(fn()=>if normalize newP andalso normalize oldP then
             tolerance(A.elements(retrieve newP))(difference(retrieve newP)(retrieve oldP))false else raise Match)
         val maximum=L.delay(fn()=>D.delay(fn()=>let val a=force(L.force toleranceU)val b=force(L.force toleranceP)
           in if a<=b then b else a end))
         val prefix=B.pieces[B.str"at time step ",B.str(signed(maxIter-n+1)),B.str":\n\n"]
         val monitor=if mon then B.pieces[
            B.str"initial presure:\n",B.delayed(fn()=>showRealArray(retrieve oldP)),B.str"\n",
            B.str"inititial velocities:\n",B.delayed(fn()=>showVelocities(retrieve oldU)),B.str"\n",
            B.str"rh1a:\n",B.delayed(fn()=>showVelocities(L.force rhs1a)),B.str"\n",
            B.str"velocities after the 1st half of step 1:\n",B.delayed(fn()=>showVelocities(retrieve u1a)),B.str"\n",
            B.str"rh1b:\n",B.delayed(fn()=>showVelocities(L.force rhs1b)),B.str"\n",
            B.str"velocities after the 2nd half of step 1:\n",B.delayed(fn()=>showVelocities(retrieve u1b)),B.str"\n",
            B.str"rh2:\n",B.delayed(fn()=>showRealArray(retrieve rhs2)),B.str"\n",
            B.str"rh3:\n",B.delayed(fn()=>showVelocities(L.force rhs3)),B.str"\n"]else B.id
         val revised=C.append result(B.output(B.cat prefix monitor))
         val final=B.output(B.pieces[B.str"presure:\n",B.delayed(fn()=>showRealArray(retrieve newP)),
           B.str"\nvelocities:\n",B.delayed(fn()=>showVelocities(retrieve newU)),B.str"\n"])
       in if n<=1 orelse lt(L.force maximum)iterTolerance then C.append revised final
          else if lt large(L.force maximum) then raise Fail"main iteration: overflow!"
          else iterate(n-1)newP newU revised end
   in iterate maxIter(pack(normalArray normalReal)(fn()=>initialPressure))
       (pack normalVelocity(fn()=>initialVelocity))(C.empty())end
 fun run config(mesh:mesh)=
   let fun delayedArray f=L.delay(fn()=>L.force(f()))
       val factors=delayedArray(fn()=>elementFactors(#elements mesh)(#coordinates mesh)(#pressureSteer mesh))
       val ordered=L.delay(fn()=>orderedMatrix(#pressureNodes mesh)factors(#pressureSteer mesh)(#fixed mesh))
       val factored=delayedArray(fn()=>cholesky(#1(L.force ordered)))
       val mapping=delayedArray(fn()=> #2(L.force ordered))
       val pressureTable=delayedArray(fn()=>getAssemblyTable(#pressureNodes mesh)(#elements mesh)3(#pressureSteer mesh))
       val velocityTable=delayedArray(fn()=>getAssemblyTable(#nodes mesh)(#elements mesh)6(#velocitySteer mesh))
   in simulate config factors velocityTable pressureTable(#velocitySteer mesh)(#pressureSteer mesh)
        (#boundary mesh)(#fixed mesh)(factored,mapping)(#initial mesh)end
