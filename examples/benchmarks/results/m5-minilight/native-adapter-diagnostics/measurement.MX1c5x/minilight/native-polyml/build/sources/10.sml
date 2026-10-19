(* Harrison Ainsworth / HXA7241, copyright 2006-2008; original BSD notice retained. *)
structure BenchMiniSurface=
struct
 structure V=BenchMiniVector
 structure T=BenchMiniTriangle
 type t={triangle:T.t,position:V.t}
 val pi=3.141592653589793238512809
 fun emission({triangle,position}:t)toPosition outDirection solid=
   let val ray=V.subtract toPosition position
       val distance2=V.dot ray ray
       val cosArea=V.dot outDirection(T.normal triangle)*T.area triangle
       val angle=if solid then cosArea/Real.max(0.000001,distance2)else 1.0
   in if cosArea>0.0 then V.scale(T.emitivity triangle)angle else V.zero end
 fun reflection({triangle,...}:t)inDirection radiance outDirection=
   let val inDot=V.dot inDirection(T.normal triangle)
       val outDot=V.dot outDirection(T.normal triangle)
       fun compareZero x=if x>0.0 then ~1 else if x<0.0 then 1 else 0
   in if compareZero inDot*compareZero outDot>0
      then V.scale(V.multiply radiance(T.reflectivity triangle))(Real.abs inDot/pi)
      else V.zero end
 fun nextDirection({triangle,...}:t)inDirection random=
   let val mean=V.dot(T.reflectivity triangle)V.one/3.0
   in if BenchOCamlRandom.real random 1.0<mean then
       let val color=V.divideScalar(T.reflectivity triangle)mean
           (* Tuple evaluation draws sr2 before the angle. *)
           val sr2=Math.sqrt(BenchOCamlRandom.real random 1.0)
           val angle=pi*2.0*BenchOCamlRandom.real random 1.0
           val coordinates=V.create(Math.cos angle*sr2)(Math.sin angle*sr2)(Math.sqrt(1.0-sr2*sr2))
           val tangent=T.tangent triangle
           val n=T.normal triangle
           val normal=if V.dot n inDirection>=0.0 then n else V.negative n
           val frame=Array.fromList[tangent,V.cross normal tangent,normal]
           val direction=V.scaleFrame frame coordinates
       in(direction,color)end
      else(V.zero,V.zero)
   end
end
