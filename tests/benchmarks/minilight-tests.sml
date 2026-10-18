structure MiniLightTests=
struct
 structure V=BenchMiniVector
 structure Triangle=BenchMiniTriangle
 structure L=BenchMiniDelay
 structure I=BenchMiniImage
 structure C=BenchMiniCheck
 fun check label f=T.check("minilight/"^label,f)
 val _=check "memoized-geometry-delay-shares"(fn()=>
   let val calls=ref 0 val delayed=L.delay(fn()=>(calls:= !calls+1;V.create 1.0 2.0 3.0))
       val a=L.force delayed val b=L.force delayed
   in !calls=1 andalso a=b end)
 val _=check "failed-delay-is-memoized"(fn()=>
   let val calls=ref 0 val delayed=L.delay(fn()=>(calls:= !calls+1;raise Fail"probe"))
       val _=(L.force delayed handle Fail _=>())
       val _=(L.force delayed handle Fail _=>())
   in !calls=1 end)
 fun triangle()=Triangle.create(Array.fromList[V.create 0.0 0.0 0.0,V.create 1.0 0.0 0.0,V.create 0.0 1.0 0.0])V.one V.zero
 val _=check "equal-geometry-has-distinct-object-identity"(fn()=>let val a=triangle()val b=triangle()in Triangle.same(a,a)andalso not(Triangle.same(a,b))end)
 val _=check "original-lazy-geometry-demand-states"(fn()=>
   let val tri=triangle()
       val Triangle.Triangle{normal,tangent,area,...}=tri
       fun ready state=case !state of L.Ready _=>true|_=>false
       fun state()=[ready normal,ready tangent,ready area]
       val a=state()val _=Triangle.area tri val b=state()
       val _=Triangle.normal tri val c=state()
       val _=Triangle.tangent tri val d=state()
   in [a,b,c,d]=[[false,false,false],[false,false,true],[true,false,true],[true,true,true]]end)
 val _=check "triangle-moller-intersection"(fn()=>
   case Triangle.intersection(triangle())(V.create 0.25 0.25 1.0)(V.create 0.0 0.0(~1.0))of
     NONE=>false|SOME d=>C.close(d,1.0))
 val _=check "triangle-parallel-ray-misses"(fn()=>case Triangle.intersection(triangle())(V.create 0.25 0.25 1.0)V.oneX of NONE=>true|_=>false)
 val _=check "triangle-geometric-area-and-normal"(fn()=>
   let val tri=triangle()val n=Triangle.normal tri
   in C.close(Triangle.area tri,0.5)andalso V.equal n V.oneZ end)
 val _=check "octree-last-hit-is-physical-identity"(fn()=>
   let val a=triangle()val b=triangle()val index=BenchMiniSpatial.create(V.create 0.25 0.25 1.0)[a,b]
       val ray=V.create 0.0 0.0(~1.0)
   in case BenchMiniSpatial.intersection index(V.create 0.25 0.25 1.0)ray(SOME a)of
     NONE=>false|SOME(hit,_)=>Triangle.same(hit,b)end)
 val _=check "unitization-keeps-zero-shared"(fn()=>V.unitize V.zero=V.zero)
 val _=check "float-checker-rejects-perturbation"(fn()=>not(C.close(1.0001,1.0)))
 val _=check "float-checker-accepts-small-roundoff"(fn()=>C.close(1.0+1.0E~10,1.0))
 val _=check "float-checker-rejects-NaN"(fn()=>not(C.close(Real.posInf-Real.posInf,1.0)))
 val _=check "raster-checker-rejects-one-byte-corruption"(fn()=>
   not(C.raster(Word8Vector.fromList[0w0,0w1,0w2])(Word8Vector.fromList[0w0,0w1,0w3])))
 val _=check "raster-checker-rejects-wrong-length"(fn()=>
   not(C.raster(Word8Vector.fromList[0w0])(Word8Vector.fromList[0w0,0w0])))
 val _=check "fixed-original-smoke-first-last-RNG-and-raster"(fn()=>C.run"smoke.model""smoke.reference"="1:40:1")
end
