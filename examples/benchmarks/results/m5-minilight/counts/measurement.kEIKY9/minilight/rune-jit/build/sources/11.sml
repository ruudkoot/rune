(* Harrison Ainsworth / HXA7241, copyright 2006-2008; original BSD notice retained. *)
structure BenchMiniRay=
struct
 structure V=BenchMiniVector
 structure T=BenchMiniTriangle
 structure S=BenchMiniScene
 structure P=BenchMiniSurface
 datatype t=Tracer of S.t
 fun create scene=Tracer scene
 fun emitterSample(Tracer scene)rayDirection(surface:P.t)random=
   case S.emitter scene random of
      (NONE,_)=>V.zero
     |(SOME emitter,point)=>
       let val direction=V.unitize(V.subtract point(#position surface))
           val incoming=case S.intersection scene(#position surface)direction(SOME(#triangle surface))of
               SOME(hit,_)=>if not(T.same(hit,emitter))then V.zero
                 else P.emission{triangle=emitter,position=point}(#position surface)(V.negative direction)true
              |NONE=>P.emission{triangle=emitter,position=point}(#position surface)(V.negative direction)true
       in P.reflection surface direction(V.scale incoming(Real.fromInt(S.emittersCount scene)))(V.negative rayDirection)end
 fun radiance(tracer as Tracer scene)origin direction last random=
   case S.intersection scene origin direction last of NONE=>S.defaultEmission scene(V.negative direction)
    |SOME(triangle,position)=>
       let val surface={triangle=triangle,position=position}
           val localEmission=case last of NONE=>P.emission surface origin(V.negative direction)false|SOME _=>V.zero
           val illumination=emitterSample tracer direction surface random
           val(next,color)=P.nextDirection surface(V.negative direction)random
           val reflected=if not(V.equal next V.zero)then
             V.multiply color(radiance tracer position next(SOME triangle)random)else V.zero
       in V.add(V.add reflected illumination)localEmission end
end
