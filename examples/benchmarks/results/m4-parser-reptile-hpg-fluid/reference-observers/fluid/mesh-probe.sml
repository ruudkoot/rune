fun read path=let val f=TextIO.openIn path in TextIO.inputAll f before TextIO.closeIn f end
functor MeshTests(D:BENCH_SUSPEND)=struct
 structure K=BenchFluidFn(D)
 structure W=Word32
 fun number n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun list f xs="["^String.concatWith","(List.map f xs)^"]"
 fun pair a b="("^a^","^b^")"
 fun bounds(a,b)=pair(number a)(number b)
 fun bits r=
   let val sign=if Real.signBit r then 0wx80000000 else 0w0
       val r=Real.abs r
       val magnitude=if Real.==(r,0.0)then 0w0 else
         let val{man,exp}=Real.toManExp r
         in if exp< ~125 then W.fromInt(Real.round(Real.fromManExp{man=r,exp=149}))
           else W.orb(W.<<(W.fromInt(exp+126),0w23),W.fromInt(Real.round(man*16777216.0)-8388608))end
   in IntInf.toString(W.toLargeInt(W.orb(sign,magnitude)))end
 fun showReal value=bits(D.force value)
 fun showRealArray a=list(fn(i,v)=>pair(number i)(showReal v))(K.F.toList(K.A.associations a))
 fun showIntArray a=list(fn(i,v)=>pair(number i)(number(D.force v)))(K.F.toList(K.A.associations a))
 fun showBoolArray a=list(fn(i,v)=>pair(number i)(if D.force v then"True"else"False"))(K.F.toList(K.A.associations a))
 fun showLists a=list(fn(i,v)=>pair(number i)(list number(K.F.toList(D.force v))))(K.F.toList(K.A.associations a))
 fun blockArray a=list(fn(i,value)=>let val(diag,off)=D.force value
       val segs=list(fn(j,value)=>let val(start,vs)=D.force value
         in pair(number j)(pair(number start)(list bits(K.F.toList vs)))end)(K.F.toList(K.A.associations off))
     in pair(number i)("("^String.concatWith","[bounds(K.A.bounds diag),showRealArray diag,bounds(K.A.bounds off),segs]^")")end)
     (K.F.toList(K.A.associations a))
 fun check name actual=let val expected=read("tests/out/benchmarks/nofib-fluid-originals/"^name^".reference")
     in if actual^"\n"=expected then print("PASS complete source "^name^"\n")
       else let val f=TextIO.openOut("tests/out/benchmarks/nofib-fluid-originals/"^name^".actual")
         in TextIO.output(f,actual^"\n");TextIO.closeOut f;raise Fail("mesh observation "^name)end end
 val header=K.input(read"tests/out/benchmarks/nofib-fluid-originals/source/fluid.stdin")
 val(file,(mon,iterations,tolerance,jacobiIterations,jacobiTolerance,relax,time))=K.readConfig header
 val _=if file="runtime_files/chan8.dat"andalso not mon andalso iterations=1 andalso jacobiIterations=2
    andalso Real.==(D.force tolerance,K.R.round 1.0e~5)
    andalso Real.==(D.force jacobiTolerance,K.R.round 0.01)
    andalso Real.==(D.force relax,1.0)andalso Real.==(D.force time,K.R.round 0.01)
   then print"PASS complete source configuration\n"else raise Fail"input configuration"
 val mesh:K.mesh=K.readMesh(K.input(read("tests/out/benchmarks/nofib-fluid-originals/source/"^file)))
 val(p,(u1,u2))= #initial mesh
 val(all,(xf,yf))= #boundary mesh
 val coord=list(fn(i,v)=>let val(x,y)=D.force v
    in pair(number i)(pair(showReal x)(showReal y))end)(K.F.toList(K.A.associations(#coordinates mesh)))
 val _=check"mesh-input"("("^String.concatWith","[
    number(#elements mesh),number(#nodes mesh),number(#pressureNodes mesh),
    showLists(#velocitySteer mesh),showLists(#pressureSteer mesh),coord,
    showRealArray p,showRealArray u1,showRealArray u2,
    showBoolArray all,showBoolArray xf,showBoolArray yf,list number(K.F.toList(#fixed mesh))]^")")
 val factors=K.elementFactors(#elements mesh)(#coordinates mesh)(#pressureSteer mesh)
 val(initial,mapping)=K.orderedMatrix(#pressureNodes mesh)factors(#pressureSteer mesh)(#fixed mesh)
 val _=check"mesh-order"(pair(blockArray initial)(showIntArray mapping))
 val factor=K.cholesky initial
 val _=check"mesh-factor"(blockArray factor)
 val b=K.A.listArray(1,#pressureNodes mesh)(K.map(fn i=>K.number(Real.fromInt(D.force i*D.force i)))(K.range 1(#pressureNodes mesh)))
 val _=check"mesh-solution"(showRealArray(K.choleskyMethod(factor,mapping)b(K.number 0.25)))
end
structure Need=MeshTests(BenchNeed)
structure Strict=MeshTests(BenchStrict)
