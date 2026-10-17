from pathlib import Path
import subprocess
p=Path(__file__).resolve().parent;obs=p/'observer-source'
# Independent original observations: each SML expression is checked against
# an exported value from the unmodified original mathematical definition.
cases=[
 ('add','K.vecadd (1,2,3) (4,5,6)','K.add(v(1.0,2.0,3.0))(v(4.0,5.0,6.0))'),
 ('sub','K.vecsub (1,2,3) (4,5,6)','K.sub(v(1.0,2.0,3.0))(v(4.0,5.0,6.0))'),
 ('mult','K.vecmult (1,2,3) (4,5,6)','K.mult(v(1.0,2.0,3.0))(v(4.0,5.0,6.0))'),
 ('cross','K.veccross (1,2,3) (4,5,6)','K.cross(v(1.0,2.0,3.0))(v(4.0,5.0,6.0))'),
 ('scale','K.vecscale (1,2,3) (-2)','K.scale(v(1.0,2.0,3.0))(K.number ~2.0)'),
 ('norm','fst(K.vecnorm (3,4,0))','K.unit(v(3.0,4.0,0.0))'),
 ('sum','K.vecsum [(1,2,3),(4,5,6),(7,8,9)]','K.vectorSum(S.fromList[v(1.0,2.0,3.0),v(4.0,5.0,6.0),v(7.0,8.0,9.0)])'),
 ('ambient-default','K.ambientsurf []','K.ambient[]'),
 ('body-default','K.bodysurf []','K.body[]'),
 ('first-surface','K.ambientsurf[K.Diffuse (7,8,9),K.Ambient (1,2,3),K.Ambient (4,5,6)]','K.ambient[K.Diffuse(v(7.0,8.0,9.0)),K.Ambient(v(1.0,2.0,3.0)),K.Ambient(v(4.0,5.0,6.0))]'),
 ('refract-front','snd(K.refractray 0.5 (0.6,0,-0.8) (0,0,1))','L.delay(fn()=>L.force(#2(L.force(K.refractRay(K.number 0.5)(v(0.6,0.0,~0.8))(v(0.0,0.0,1.0))))))'),
 ('refract-back','snd(K.refractray 1.5 (0.6,0,0.8) (0,0,1))','L.delay(fn()=>L.force(#2(L.force(K.refractRay(K.number 1.5)(v(0.6,0.0,0.8))(v(0.0,0.0,1.0))))))'),
 ('refract-tir','snd(K.refractray 1.5 (sqrt 0.75,0,-0.5) (0,0,1))','L.delay(fn()=>L.force(#2(L.force(K.refractRay(K.number 1.5)(v(Math.sqrt 0.75,0.0,~0.5))(v(0.0,0.0,1.0))))))'),
 ('empty-lights-shade','K.shade [] (K.Sphere (0,0,0) 0.5 [K.Ambient (0.2,0.3,0.4)]) (0,0,2) (0,0,-1) 1.5 (1,1,1)',
  'K.shade[](K.Sphere(v(0.0,0.0,0.0),K.number 0.5,[K.Ambient(v(0.2,0.3,0.4))]))(v(0.0,0.0,2.0))(v(0.0,0.0,~1.0))(K.number 1.5)(v(1.0,1.0,1.0))')]
haskell='module Main where\nimport qualified Kernel as K\nmain=mapM_ (\\(name,(x,y,z))->putStrLn(unwords[name,show x,show y,show z]))\n ['+',\n  '.join('("'+name+'",'+expr+')'for name,expr,_ in cases)+']\n'
(obs/'Samples.hs').write_text(haskell)
with(obs/'samples-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','-o','samples','Samples.hs'],cwd=obs,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(obs/'samples')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,check=True);(p/'vectors.reference').write_bytes(r.stdout)
body=r'''
 structure K=BenchSphereFn(D)
 structure Driver=BenchSphereDriverFn(K)
 structure L=BenchLazy
 structure S=BenchStream
 fun v xyz=K.vector xyz
 fun label s="sphere/"^policy^"/"^s
 val base="PRIVATE/"
 fun read file=Driver.read(base^file)
 fun refrow row=case String.tokens Char.isSpace row of[name,r,g,b]=>(name,(Driver.real r,Driver.real g,Driver.real b))
   |_=>raise Fail "bad sphere vector fixture"
 val references=List.map refrow(String.tokens(fn c=>c= #"\n")(read"vectors.reference"))
 fun expected name=case List.find(fn(key,_)=>key=name)references of SOME(_,value)=>value|NONE=>raise Fail "missing vector reference"
 fun observe name make=T.check(label name,fn()=>Driver.valid(K.components(make()),expected name))
 SAMPLES
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
'''
samples='\n'.join(' val _=observe"'+name+'"(fn()=>'+expr+')'for name,_,expr in cases)
text='functor SphereTestsFn(P:sig structure D:BENCH_SUSPEND val policy:string end)=struct\n structure D=P.D\n val policy=P.policy\n'+body.replace('PRIVATE',str(p)).replace('SAMPLES',samples)+'\nend\n'
text=text.replace('Driver.valid(K.components(K.ambient(K.surface(L.force chosen))),(1.0,0.0,0.0))','Driver.valid(K.components(K.ambient(K.surface(L.force chosen))),(1.0,0.0,0.0))')
text+='structure NeedTests=SphereTestsFn(struct structure D=BenchNeed val policy="lazy"end)\nstructure StrictTests=SphereTestsFn(struct structure D=BenchStrict val policy="strict"end)\n'
(p/'tests.sml').write_text(text)
