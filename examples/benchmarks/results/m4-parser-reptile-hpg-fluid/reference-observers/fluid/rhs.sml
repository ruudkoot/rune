 fun member n values=case force values of F.Nil=>false
   |F.Cons(x,rest)=>force x=n orelse member n rest
 fun getRhs1(elementFactors:elementFactor A.array)table velocitySteer pressureSteer(pressure,(u1,u2))=
   let
     fun contribution entry=D.delay(fn()=>
       let val(e,id)=force entry
           val(det,factors as(fx,fy))=force(A.lookup elementFactors e)
           val gradient=force(A.lookup gradientMatrix id)
           val diffusion=force(A.lookup diffusionMatrix id)factors
           val velocity=(getValues u1(force(A.lookup velocitySteer e)),getValues u2(force(A.lookup velocitySteer e)))
           val pressures=getValues pressure(force(A.lookup pressureSteer e))
           val convection=force(A.lookup convectionMatrix id)factors velocity
           fun component values factor=mul
             (add(add(divide(listMatchProd values diffusion)(number(~3.0)))
                (divide(listMatchProd values convection)(number(~1260.0))))
                (divide(listMatchProd pressures(gradient factor))(number 3.0)))det
       in(component(#1 velocity)fx,component(#2 velocity)fy)end)
     val pairs=map(fn entries=>cell(map contribution(force entries)))(A.elements table)
     fun component select=A.listArray(A.bounds table)
       (map(fn row=>sum(map(fn p=>select(force p))(force row)))pairs)
   in(component #1,component #2)end
 fun getRhs2(elementFactors:elementFactor A.array)table velocitySteer pressureFixed(u1,u2)=
   let val bnds=A.bounds table
       fun row i=D.delay(fn()=>if member(force i)pressureFixed then 0.0 else
         force(divide(sum(map(fn entry=>D.delay(fn()=>
          let val(e,id)=force entry
              val steering=force(A.lookup velocitySteer e)
              val(det,factors as(fx,fy))=force(A.lookup elementFactors e)
              val gradient=force(A.lookup transposedGradient id)
          in force(mul(add(listMatchProd(getValues u1 steering)(gradient fx))
                    (listMatchProd(getValues u2 steering)(gradient fy)))det)end))
              (force(A.lookup table(force i)))))(number(~3.0))))
   in A.defListArray eq bnds zero(map row(range(#1 bnds)(#2 bnds)))end
 fun getRhs3(elementFactors:elementFactor A.array)table pressureSteer deltaPressure=
   let
     fun contribution entry=D.delay(fn()=>
       let val(e,id)=force entry val gradient=force(A.lookup gradientMatrix id)
           val pressures=getValues deltaPressure(force(A.lookup pressureSteer e))
           val(det,(fx,fy))=force(A.lookup elementFactors e)
       in(mul det(listMatchProd pressures(gradient fx)),mul det(listMatchProd pressures(gradient fy)))end)
     val pairs=map(fn entries=>cell(map contribution(force entries)))(A.elements table)
     fun component select=A.amap(fn x=>divide x(number 3.0))
       (A.listArray(A.bounds table)(map(fn row=>sum(map(fn p=>select(force p))(force row)))pairs))
   in(component #1,component #2)end
