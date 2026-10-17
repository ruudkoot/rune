functor SphereTestsFn(P:sig structure D:BENCH_SUSPEND val policy:string end)=struct
 structure D=P.D
 val policy=P.policy

 structure K=BenchSphereFn(D)
 structure Driver=BenchSphereDriverFn(K)
 structure L=BenchLazy
 structure S=BenchStream
 fun v xyz=K.vector xyz
 fun label s="sphere/"^policy^"/"^s
 val base=""
 fun read file=Driver.read(base^file)
 fun refrow row=case String.tokens Char.isSpace row of[name,r,g,b]=>(name,(Driver.real r,Driver.real g,Driver.real b))
   |_=>raise Fail "bad sphere vector fixture"
 val references=List.map refrow(String.tokens(fn c=>c= #"\n")(read"vectors.reference"))
 fun expected name=case List.find(fn(key,_)=>key=name)references of SOME(_,value)=>value|NONE=>raise Fail "missing vector reference"
 fun observe name make=T.check(label name,fn()=>Driver.valid(K.components(make()),expected name))
  val _=observe"add"(fn()=>K.add(v(1.0,2.0,3.0))(v(4.0,5.0,6.0)))
 val _=observe"sub"(fn()=>K.sub(v(1.0,2.0,3.0))(v(4.0,5.0,6.0)))
 val _=observe"mult"(fn()=>K.mult(v(1.0,2.0,3.0))(v(4.0,5.0,6.0)))
 val _=observe"cross"(fn()=>K.cross(v(1.0,2.0,3.0))(v(4.0,5.0,6.0)))
 val _=observe"scale"(fn()=>K.scale(v(1.0,2.0,3.0))(K.number ~2.0))
 val _=observe"norm"(fn()=>K.unit(v(3.0,4.0,0.0)))
 val _=observe"sum"(fn()=>K.vectorSum(S.fromList[v(1.0,2.0,3.0),v(4.0,5.0,6.0),v(7.0,8.0,9.0)]))
 val _=observe"ambient-default"(fn()=>K.ambient[])
 val _=observe"body-default"(fn()=>K.body[])
 val _=observe"first-surface"(fn()=>K.ambient[K.Diffuse(v(7.0,8.0,9.0)),K.Ambient(v(1.0,2.0,3.0)),K.Ambient(v(4.0,5.0,6.0))])
 val _=observe"refract-front"(fn()=>L.delay(fn()=>L.force(#2(L.force(K.refractRay(K.number 0.5)(v(0.6,0.0,~0.8))(v(0.0,0.0,1.0)))))))
 val _=observe"refract-back"(fn()=>L.delay(fn()=>L.force(#2(L.force(K.refractRay(K.number 1.5)(v(0.6,0.0,0.8))(v(0.0,0.0,1.0)))))))
 val _=observe"refract-tir"(fn()=>L.delay(fn()=>L.force(#2(L.force(K.refractRay(K.number 1.5)(v(Math.sqrt 0.75,0.0,~0.5))(v(0.0,0.0,1.0)))))))
 val _=observe"empty-lights-shade"(fn()=>K.shade[](K.Sphere(v(0.0,0.0,0.0),K.number 0.5,[K.Ambient(v(0.2,0.3,0.4))]))(v(0.0,0.0,2.0))(v(0.0,0.0,~1.0))(K.number 1.5)(v(1.0,1.0,1.0)))
 val sphere=K.Sphere(v(0.0,0.0,0.0),K.number 0.5,[])
 fun intersection(name,pos,dir,hit,distance)=T.check(label name,fn()=>
   let val(actual,d)=L.force(K.intersect(v pos)(v dir)sphere)
   in actual=hit andalso Real.==(K.value d,distance)end)
 val _=List.app intersection[
  ("hit-front",(0.0,0.0,2.0),(0.0,0.0,~1.0),true,1.5),
  ("hit-inside",(0.0,0.0,0.0),(0.0,0.0,1.0),true,0.5),
  ("miss-away",(0.0,0.0,2.0),(0.0,0.0,1.0),false,0.0),
  ("miss-disc",(2.0,0.0,2.0),(0.0,0.0,~1.0),false,0.0),
  ("tangent",(0.5,0.0,2.0),(0.0,0.0,~1.0),true,2.0),
  ("surface-zero-distance",(0.0,0.0,0.5),(0.0,0.0,~1.0),true,0.0)]
 val _=T.check(label"source-signed-zero-cutoff",fn()=>K.isZero(v(~1.0,~2.0,~3.0)))
 val _=T.check(label"nonzero-cutoff-component",fn()=>not(K.isZero(v(~1.0,1.0E~5,~3.0))))
 val _=T.check(label"total-internal-reflection-flag",fn()=>
   #1(L.force(K.refractRay(K.number 1.5)(v(Math.sqrt 0.75,0.0,~0.5))(v(0.0,0.0,1.0)))))
 val _=T.check(label"empty-world-misses-without-sphere",fn()=>
   not(#1(L.force(K.trace[](v(0.0,0.0,2.0))(v(0.0,0.0,~1.0))))))
 val _=T.check(label"source-nearest-tie-keeps-base-head",fn()=>
   let fun ball color=K.Sphere(v(0.0,0.0,0.0),K.number 0.5,[K.Ambient color])
       val a=ball(v(1.0,0.0,0.0))val b=ball(v(0.0,1.0,0.0))
       val(_,_,chosen)=L.force(K.trace[a,b](v(0.0,0.0,2.0))(v(0.0,0.0,~1.0)))
   in Driver.valid(K.components(K.ambient(K.surface(L.force chosen))),(1.0,0.0,0.0))end)
 val _=T.check(label"complete-smoke-image",fn()=>
   Driver.run["1","30",base^"smoke.pixels"]="1:900 1F1C163343ECB0F8")
 val wanted=Driver.reference(read"smoke.pixels")
 val _=T.check(label"finite-numeric-tolerance-interior",fn()=>Driver.valid((1.0+1.0E~10,0.0,0.0),(1.0,0.0,0.0)))
 val _=T.check(label"perturbed-channel-rejected",fn()=>not(Driver.valid((1.001,0.0,0.0),(1.0,0.0,0.0))))
 val _=T.check(label"NaN-rejected",fn()=>not(Driver.valid((0.0/0.0,0.0,0.0),(0.0,0.0,0.0))))
 val _=T.check(label"quantization-halfway-even",fn()=>Driver.quantize(0.5/255.0,2.5/255.0,~0.5/255.0)=(0,2,0))
 val _=T.check(label"changed-coordinate-rejected",fn()=>
   case wanted of(i,j,rgb,rounded)::rest=>
    ((Driver.consume((i+1,j,rgb,rounded)::rest)(K.ray 30);false)handle Fail _=>true)
   |_=>false)
 val _=T.check(label"short-image-reference-rejected",fn()=>
   ((Driver.consume[](K.ray 30);false)handle Fail _=>true))

end
structure NeedTests=SphereTestsFn(struct structure D=BenchNeed val policy="lazy"end)
structure StrictTests=SphereTestsFn(struct structure D=BenchStrict val policy="strict"end)
structure SphereDemandTests=struct
 structure K=BenchSphereFn(BenchNeed)
 structure Driver=BenchSphereDriverFn(K)
 structure S=BenchStream
 structure L=BenchLazy
 val _=T.check("sphere/demand/unused-vector-coordinate",fn()=>
   let val x=BenchNeed.delay(fn()=>2.0)
       val bad=BenchNeed.delay(fn()=>raise Fail "unused coordinate")
       val vector=L.delay(fn()=>K.V(x,bad,bad))
       val K.V(result,_,_)=L.force(K.scale vector(K.number 3.0))
   in Real.==(K.value result,6.0)end)
 val _=T.check("sphere/demand/shared-scalar-payload",fn()=>
   let val count=ref 0 val x=BenchNeed.delay(fn()=>(count:= !count+1;2.0))
       val v=L.delay(fn()=>K.V(x,K.number 0.0,K.number 0.0))
       val result=K.value(K.dot v v)
   in Real.==(result,4.0)andalso !count=1 end)
 val _=T.check("sphere/source/right-associated-vector-sum",fn()=>
   let val(a,b,c)=K.components(K.vectorSum(S.fromList[
          K.vector(1.0E16,0.0,0.0),K.vector(~1.0E16,0.0,0.0),K.vector(1.0,0.0,0.0)]))
   in Real.==(a,0.0)andalso Real.==(b,0.0)andalso Real.==(c,0.0)end)
 val _=T.check("sphere/checker/nonfinite-reference-rejected",fn()=>
   ((Driver.reference"0 0 nan 0 0 0 0 0\n";false)handle Fail _=>true))
 val _=T.check("sphere/checker/malformed-row-rejected",fn()=>
   ((Driver.reference"0 0 1.0\n";false)handle Fail _=>true))
end
