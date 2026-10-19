(* Harrison Ainsworth / HXA7241, copyright 2006-2008; original BSD notice retained. *)
structure BenchMiniScene=
struct
 structure V=BenchMiniVector
 structure T=BenchMiniTriangle
 datatype t=Scene of{triangles:T.t array,emitters:T.t array,index:BenchMiniSpatial.tree,
   sky:V.t,ground:V.t}
 fun read input eye=
   let val sky=BenchMiniParse.vector input
       val ground=BenchMiniParse.vector input
       fun readTriangles acc 0=acc
         |readTriangles acc n=
           (let val triangle=T.read input in readTriangles(triangle::acc)(n-1)end
             handle BenchMiniParse.End=>acc)
       val triangles=readTriangles[]1048576
       fun isEmitter item=not(V.equal(T.emitivity item)V.zero)andalso T.area item>0.0
       val emitters=List.filter isEmitter triangles
       val index=BenchMiniSpatial.create eye triangles
   in Scene{triangles=Array.fromList triangles,emitters=Array.fromList emitters,index=index,
      sky=V.clamp V.zero V.maximum sky,ground=V.clamp V.zero V.one ground}end
 fun intersection(Scene{index,...})origin direction last=
   BenchMiniSpatial.intersection index origin direction last
 fun emittersCount(Scene{emitters,...})=Array.length emitters
 fun emitter(scene as Scene{emitters,...})random=
   if emittersCount scene>0 then
     let val item=Array.sub(emitters,BenchOCamlRandom.integer random(emittersCount scene))
         val point=T.sample item random
     in(SOME item,point)end
   else(NONE,V.zero)
 fun defaultEmission(Scene{sky,ground,...})eyeDirection=
   if V.dot eyeDirection V.oneY<0.0 then sky else V.multiply sky ground
end
