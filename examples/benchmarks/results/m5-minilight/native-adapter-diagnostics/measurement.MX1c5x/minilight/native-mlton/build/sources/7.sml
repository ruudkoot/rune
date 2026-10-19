(* Harrison Ainsworth / HXA7241, copyright 2006-2008; original BSD notice retained. *)
structure BenchMiniTriangle=
struct
 structure V=BenchMiniVector
 structure L=BenchMiniDelay
 datatype t=Triangle of{identity:unit ref,vertices:V.t array,edge0:V.t,edge1:V.t,edge3:V.t,
   normal:V.t L.t,tangent:V.t L.t,area:real L.t,reflectivity:V.t,emitivity:V.t}
 val tolerance=1.0/1024.0
 fun create vertices reflectivity emitivity=
   let val e0=V.subtract(Array.sub(vertices,1))(Array.sub(vertices,0))
       val e1=V.subtract(Array.sub(vertices,2))(Array.sub(vertices,1))
       val e3=V.subtract(Array.sub(vertices,2))(Array.sub(vertices,0))
   in Triangle{identity=ref(),vertices=vertices,edge0=e0,edge1=e1,edge3=e3,
      normal=L.delay(fn()=>V.unitize(V.cross e0 e1)),tangent=L.delay(fn()=>V.unitize e0),
      area=L.delay(fn()=>0.5*V.length(V.cross e0 e1)),
      reflectivity=V.clamp V.zero V.one reflectivity,emitivity=V.clamp V.zero V.maximum emitivity}end
 fun read input=
   let fun vectors acc 0=acc|vectors acc n=vectors(BenchMiniParse.vector input::acc)(n-1)
       val values=vectors[]5
   in create(Array.fromList[List.nth(values,4),List.nth(values,3),List.nth(values,2)])
        (List.nth(values,1))(List.nth(values,0))end
 fun same(Triangle{identity=a,...},Triangle{identity=b,...})=a=b
 fun normal(Triangle{normal,...})=L.force normal
 fun tangent(Triangle{tangent,...})=L.force tangent
 fun area(Triangle{area,...})=L.force area
 fun reflectivity(Triangle{reflectivity,...})=reflectivity
 fun emitivity(Triangle{emitivity,...})=emitivity
 fun bounds(Triangle{vertices,...})=
   let fun expand clamp nudge=
         let val reduced=V.zip clamp(Array.sub(vertices,0))
               (V.zip clamp(Array.sub(vertices,1))(Array.sub(vertices,2)))
         in V.zip(fn a=>fn b=>nudge b((Real.abs b+a)*tolerance))V.one reduced end
       (* The outer OCaml array literal evaluates its high element first. *)
       val high=expand(fn a=>fn b=>Real.max(a,b))(fn b=>fn e=>b+e)
       val low=expand(fn a=>fn b=>Real.min(a,b))(fn b=>fn e=>b-e)
   in Array.fromList[low,high]end
 fun intersection(Triangle{vertices,edge0,edge3,...})origin direction=
   let val p=V.cross direction edge3
       val determinant=V.dot edge0 p
   in if determinant> ~0.000001 andalso determinant<0.000001 then NONE
      else let val inverse=1.0/determinant
               val t=V.subtract origin(Array.sub(vertices,0))
               val u=V.dot t p*inverse
           in if u<0.0 orelse u>1.0 then NONE
              else let val q=V.cross t edge0
                       val v=V.dot direction q*inverse
                   in if v<0.0 orelse u+v>1.0 then NONE
                      else let val distance=V.dot edge3 q*inverse
                           in if distance>=0.0 then SOME distance else NONE end
                   end
           end
   end
 fun sample(Triangle{vertices,edge0,edge3,...})random=
   let (* Tuple evaluation draws r2 before sqrt(r1). *)
       val r2=BenchOCamlRandom.real random 1.0
       val sqrt1=Math.sqrt(BenchOCamlRandom.real random 1.0)
       val coordinates=V.create 1.0(1.0-sqrt1)((1.0-r2)*sqrt1)
   in V.scaleFrame(Array.fromList[Array.sub(vertices,0),edge0,edge3])coordinates end
end
