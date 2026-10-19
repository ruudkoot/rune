functor NofibFluidSparseTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure X=BenchFluidSparseFn(D)
 structure F=X.F
 structure L=BenchLazy
 fun number n=String.map(fn #"~"=> #"-"|c=>c)(Int.toString n)
 fun tuple(a,b)="("^number a^","^number b^")"
 fun showTrie root=case L.force root of X.Null=>"N"|X.Leaf v=>"L"^number(D.force v)
   |X.Fork(a,b)=>"F("^showTrie a^","^showTrie b^")"
 fun showAssociations values="["^String.concatWith","(List.map(fn(i,v)=>tuple(i,D.force v))(F.toList values))^"]"
 fun dump a=let val X.Array(bnds,size,default,root)=L.force a
   in String.concatWith"|"[tuple bnds,number size,case default of NONE=>"Nothing"|SOME v=>"Just "^number(D.force v),
      showTrie root,showAssociations(X.associations a),showAssociations(X.sparseAssociations a)]end
 fun pairs values=F.fromList(List.map(fn(i,v)=>(i,X.cell v))values)
 val input=TextIO.openIn"tests/benchmarks/data/nofib-fluid/sparse.reference"
 val index=ref 0
 fun check a=let val actual=dump a
     val expected=case TextIO.inputLine input of NONE=>raise Fail"oracle EOF"
       |SOME s=>String.substring(s,0,size s-1)
   in BenchApplicationTestIO.compare("nofib-fluid/sparse/"^label^"/"^Int.toString(!index),expected,actual);index:= !index+1 end

 fun eq a b=D.force a=D.force b
 fun add a b=D.delay(fn()=>D.force a+D.force b)
 fun sub a b=D.delay(fn()=>D.force a-D.force b)
 fun run(lo,hi,values,updates,acc)=let
     val a=X.listArray(lo,hi)(F.fromList values)
     val b=X.defListArray eq(lo,hi)(X.cell 0)(F.fromList values)
     val arrays=[a,b,X.update eq a(pairs updates),X.update eq b(pairs updates),
       X.accum eq sub a(pairs acc),X.accum eq sub b(pairs acc),
       X.amap(fn v=>D.delay(fn()=>2*D.force v))b,
       X.ixmap(lo,hi)(fn i=>hi-(i-lo))a,
       X.accumArray eq add(X.cell 0)(lo,hi)(pairs(acc@acc)),
       X.defArray eq(lo,hi)(X.cell 0)(pairs(ListPair.zip(List.tabulate(length values,fn n=>lo+n),values)))]
   in List.app check arrays end
 val _=List.app run [(~3,~4,[],[],[]),(~3,~3,[~3],[(~3,~1)],[(~3,1),(~3,0),(~3,2),(~3,1),(~3,0),(~3,0),(~3,1)]),(~3,~2,[~3,2],[(~3,2),(~2,1)],[(~2,~1),(~3,~2),(~3,~1),(~3,~2),(~2,2),(~2,1),(~3,2)]),(~3,~1,[~3,4,5],[(~1,1),(~3,2),(~2,~4)],[(~1,0),(~1,~2),(~2,1),(~3,~2),(~2,~1),(~3,2),(~3,1)]),(~3,0,[2,4,4,1],[(0,3),(~3,1),(~1,2)],[(~1,1),(~3,~2),(~1,~1),(~1,0),(0,~3),(~3,0),(~1,~3)]),(~3,1,[~3,5,3,2,4],[(1,~5),(0,3),(~1,3)],[(~3,0),(0,0),(~2,0),(~3,~2),(0,3),(1,2),(1,2)]),(~3,3,[~2,~3,0,2,1,~5,~4],[(~2,2),(1,~1),(3,~1)],[(0,~3),(~2,~1),(~3,~1),(~2,~2),(3,1),(0,1),(~3,0)]),(~3,4,[~3,4,~2,~5,0,0,~3,~4],[(3,~3),(~2,~4),(~3,~1)],[(~2,1),(0,0),(0,0),(2,2),(4,~1),(2,1),(0,0)]),(~3,5,[~2,~5,5,5,~3,~3,2,~3,~2],[(3,1),(~3,~4),(4,~3)],[(~2,~3),(4,3),(~1,~2),(~3,~1),(~1,0),(~1,~3),(~3,~2)]),(~3,11,[1,1,0,2,5,0,~4,5,3,5,~5,1,4,5,0],[(10,~4),(6,~2),(~3,2)],[(2,~1),(~1,1),(~1,~2),(10,1),(2,~1),(8,0),(1,3)]),(~3,12,[4,~3,~2,~3,0,~5,0,~1,2,2,~1,2,~3,1,~1,5],[(12,1),(2,~1),(~1,~4)],[(~2,~2),(10,~3),(4,2),(~1,~1),(9,~2),(8,~3),(3,3)]),(~3,13,[5,~2,~2,2,1,2,~1,~5,3,~2,~5,0,3,0,~1,1,5],[(4,2),(2,~4),(5,2)],[(~2,~2),(6,~1),(10,0),(~3,0),(~1,0),(~2,0),(2,~1)]),(~3,27,[0,~5,3,~3,2,1,2,4,1,~2,~4,5,~5,~3,~3,4,~4,2,~2,~4,~5,~4,5,0,~2,~1,~3,~2,5,2,2],[(15,1),(20,~4),(10,~2)],[(10,3),(~2,3),(10,~3),(~2,~3),(5,~3),(5,3),(6,~1)])]
 val _=TextIO.closeIn input
end
structure NeedSparse=NofibFluidSparseTestsFn(structure D=BenchNeed val label="lazy")
structure StrictSparse=NofibFluidSparseTestsFn(structure D=BenchStrict val label="strict")

functor NofibFluidNumericTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchFluidFn(D)
 structure W=Word32
 fun decode word=let
     val exponent=W.toInt(W.andb(W.>>(word,0w23),0wxFF))
     val fraction=W.toInt(W.andb(word,0wx7FFFFF))
     val value=if exponent=0 then Real.fromManExp{man=Real.fromInt fraction,exp= ~149}
       else Real.fromManExp{man=Real.fromInt(8388608+fraction),exp=exponent-150}
   in if W.andb(word,0wx80000000)=0w0 then value else ~value end
 val input=TextIO.openIn"tests/benchmarks/data/nofib-fluid/numeric.reference"
 val count=ref 0
 fun check name values=let
     val line=case TextIO.inputLine input of SOME line=>line|NONE=>raise Fail"numeric oracle EOF"
     val fields=String.tokens(fn c=>c= #"|"orelse c= #","orelse c= #"\n")line
     val expected=case fields of title::values=>if title=name then
        List.map(fn s=>decode(W.fromLargeInt(valOf(IntInf.fromString s))))values
          else raise Fail"numeric oracle label"|_=>raise Fail"numeric oracle row"
     val actual=K.F.toList values
     val _=ListPair.appEq(fn(a,b)=>
       (T.check("nofib-fluid/"^label^"/binary32/"^name^"/"^Int.toString(!count),
          fn()=>Real.==(a,b)andalso Real.signBit a=Real.signBit b);count:= !count+1))(actual,expected)
   in()end

 fun list values=K.F.fromList(List.map K.R.round values)
 fun triple(a,b,c)=(K.number a,K.number b,K.number c)
 val cases=[((1.0,2.0,3.0),(4.0,5.0,6.0)),((0.125,~0.25,0.5),(~0.75,1.25,2.5)),
    ((0.0,0.0,0.0),(0.0,0.0,0.0)),((~3.0,2.0,0.33333334),(0.14285715,~5.0,9.0))]
 fun functions funcs f=K.concat(K.map(fn value=>K.cell(f(D.force value)))(K.A.elements funcs))
 val _=check"mass-row-sums"(K.A.elements K.massRowSums)
 val _=check"mass-matrix"(K.concat(K.A.elements K.massMatrix))
 val _=check"subnormal"(K.singleton K.small)
 val _=List.app(fn(i,(a,b))=>let val a=triple a val b=triple b val suffix=Int.toString i
   in check("diffusion-"^suffix)(functions K.diffusionMatrix(fn f=>f(a,b)));
      check("gradient-a-"^suffix)(functions K.gradientMatrix(fn f=>f a));
      check("gradient-b-"^suffix)(functions K.transposedGradient(fn f=>f b));
      check("convection-"^suffix)(functions K.convectionMatrix(fn f=>
        f(a,b)(list[1.0,2.0,3.0,4.0,5.0,6.0],list[6.0,5.0,4.0,3.0,2.0,1.0])))end)
    (ListPair.zip(List.tabulate(4,fn i=>i),cases))
 val _=check"inner"(K.singleton(K.listInnerProd(list[1.0,2.0,3.0,4.0])(list[0.125,~0.25,0.5,~0.75])))
 val _=check"match"(K.singleton(K.listMatchProd(list[1.0,2.0,3.0,4.0])(list[0.125,~0.25,0.5,~0.75])))
 val _=check"tolerances"(K.F.cons(K.tolerance(list[1.0,2.0,3.0])(list[0.1,~0.2,0.3])false,
   K.F.cons(K.tolerance(list[0.1,0.2,0.3])(list[0.01,~0.02,0.03])false,
   K.F.cons(K.tolerance(list[0.1,0.2,0.3])(list[0.01,~0.02,0.03])true,K.F.empty()))))
 val _=TextIO.closeIn input
 val _=T.check("nofib-fluid/"^label^"/binary32-observation-count",fn()=> !count=480)
end
structure NeedNumeric=NofibFluidNumericTestsFn(structure D=BenchNeed val label="lazy")
structure StrictNumeric=NofibFluidNumericTestsFn(structure D=BenchStrict val label="strict")

functor NofibFluidOrderingTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchFluidFn(D)
 val input=TextIO.openIn"tests/benchmarks/data/nofib-fluid/ordering.reference"
 fun show values="["^String.concatWith","(List.map Int.toString(K.F.toList values))^"]\n"
 fun check(index,rows)=let
   val inputRows=K.A.listArray(1,List.length rows)(K.F.fromList(List.map K.F.fromList rows))
   val actual=show(K.minDegree inputRows)
   val expected=case TextIO.inputLine input of SOME s=>s|NONE=>raise Fail"ordering oracle EOF"
   in BenchApplicationTestIO.compare("nofib-fluid/"^label^"/ordering/"^Int.toString index,expected,actual)end

 val cases=[[[1]], [[1]], [[1], [2]], [[1, 2], [1, 2]], [[1], [2], [3]], [[1], [2, 3], [2, 3]], [[1, 4], [2], [3], [1, 4]], [[1], [2], [3, 4], [3, 4]], [[1], [2, 4], [3], [2, 4, 5], [4, 5]], [[1, 5], [2, 3, 4], [2, 3, 4, 5], [2, 3, 4, 5], [1, 3, 4, 5]], [[1, 4], [2], [3], [1, 4], [5, 6, 8], [5, 6, 8], [7], [5, 6, 8]], [[1, 3, 4, 5, 6, 8], [2, 7, 8], [1, 3, 4, 6, 7, 8], [1, 3, 4, 7, 8], [1, 5, 7, 8], [1, 3, 6], [2, 3, 4, 5, 7], [1, 2, 3, 4, 5, 8]], [[1], [2], [3], [4, 6], [5, 7, 12], [4, 6, 7], [5, 6, 7, 11], [8, 10], [9], [8, 10], [7, 11, 12], [5, 11, 12]], [[1, 3, 4, 5, 8, 9, 11, 12], [2, 3, 4, 8, 12], [1, 2, 3, 4, 7, 10], [1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12], [1, 4, 5, 8, 10, 12], [6, 8, 9, 10, 11, 12], [3, 4, 7, 9, 10, 11], [1, 2, 4, 5, 6, 8, 9, 10, 11], [1, 4, 6, 7, 8, 9, 11], [3, 4, 5, 6, 7, 8, 10, 11, 12], [1, 4, 6, 7, 8, 9, 10, 11, 12], [1, 2, 4, 5, 6, 10, 11, 12]], [[1, 14], [2, 3], [2, 3, 4, 8], [3, 4, 5, 6, 8, 13, 14], [4, 5], [4, 6, 11, 15], [7, 16], [3, 4, 8], [9], [10, 12, 13], [6, 11], [10, 12], [4, 10, 13], [1, 4, 14, 15], [6, 14, 15], [7, 16]], [[1, 2, 3, 4, 5, 6, 8, 11, 12, 14, 16], [1, 2, 3, 7, 8, 10, 11, 12, 13, 14, 15], [1, 2, 3, 4, 8, 9, 10, 15, 16], [1, 3, 4, 8, 13, 15, 16], [1, 5, 6, 7, 8, 9, 11, 12, 13, 14, 16], [1, 5, 6, 7, 8, 9, 10, 12, 14, 16], [2, 5, 6, 7, 8, 14], [1, 2, 3, 4, 5, 6, 7, 8, 10, 13, 14, 15, 16], [3, 5, 6, 9, 10, 14, 16], [2, 3, 6, 8, 9, 10, 11, 12, 13, 14, 16], [1, 2, 5, 10, 11, 12, 15, 16], [1, 2, 5, 6, 10, 11, 12, 13, 15], [2, 4, 5, 8, 10, 12, 13, 15, 16], [1, 2, 5, 6, 7, 8, 9, 10, 14], [2, 3, 4, 8, 11, 12, 13, 15], [1, 3, 4, 5, 6, 8, 9, 10, 11, 13, 16]], [[1, 14, 22, 24], [2, 6], [3, 13, 20], [4], [5, 8, 21], [2, 6, 16, 19], [7, 24], [5, 8, 20, 24], [9, 10, 18, 24], [9, 10, 14, 17, 22], [11, 23], [12, 14, 19, 21, 22], [3, 13, 22], [1, 10, 12, 14, 16], [15], [6, 14, 16, 17, 21], [10, 16, 17, 20], [9, 18, 21, 22, 24], [6, 12, 19, 23], [3, 8, 17, 20, 23], [5, 12, 16, 18, 21, 22], [1, 10, 12, 13, 18, 21, 22], [11, 19, 20, 23], [1, 7, 8, 9, 18, 24]], [[1, 2, 5, 6, 8, 9, 10, 11, 12, 13, 16, 17, 19, 23, 24], [1, 2, 3, 6, 7, 8, 9, 10, 11, 13, 14, 15, 17, 19, 20, 21, 22, 23], [2, 3, 4, 6, 8, 9, 14, 15, 16, 18, 19, 24], [3, 4, 8, 9, 12, 13, 14, 16, 17, 18, 20, 21, 22, 23, 24], [1, 5, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 20, 24], [1, 2, 3, 6, 7, 8, 9, 12, 16, 21, 22, 23], [2, 6, 7, 8, 10, 12, 13, 16, 18, 22, 23], [1, 2, 3, 4, 6, 7, 8, 10, 11, 12, 13, 14, 16, 17, 24], [1, 2, 3, 4, 5, 6, 9, 11, 12, 13, 15, 16, 18, 19, 20, 21, 22, 24], [1, 2, 5, 7, 8, 10, 11, 12, 15, 18, 21, 22, 24], [1, 2, 5, 8, 9, 10, 11, 12, 13, 15, 16, 18, 19, 20, 23], [1, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 18, 19, 21, 22, 23, 24], [1, 2, 4, 5, 7, 8, 9, 11, 12, 13, 14, 19, 20, 21, 22, 23], [2, 3, 4, 5, 8, 13, 14, 16, 21, 23, 24], [2, 3, 9, 10, 11, 12, 15, 16, 19, 20, 22, 23, 24], [1, 3, 4, 5, 6, 7, 8, 9, 11, 12, 14, 15, 16, 17, 18, 20, 23, 24], [1, 2, 4, 5, 8, 16, 17, 18, 21, 22, 24], [3, 4, 5, 7, 9, 10, 11, 12, 16, 17, 18, 21, 23], [1, 2, 3, 5, 9, 11, 12, 13, 15, 19, 20, 21, 22, 24], [2, 4, 5, 9, 11, 13, 15, 16, 19, 20, 23, 24], [2, 4, 6, 9, 10, 12, 13, 14, 17, 18, 19, 21, 22, 24], [2, 4, 6, 7, 9, 10, 12, 13, 15, 17, 19, 21, 22, 23], [1, 2, 4, 6, 7, 11, 12, 13, 14, 15, 16, 18, 20, 22, 23, 24], [1, 3, 4, 5, 8, 9, 10, 12, 14, 15, 16, 17, 19, 20, 21, 23, 24]]]
 val _=List.app check(ListPair.zip(List.tabulate(List.length cases,fn i=>i),cases))
 val _=TextIO.closeIn input
end
structure NeedOrdering=NofibFluidOrderingTestsFn(structure D=BenchNeed val label="lazy")
structure StrictOrdering=NofibFluidOrderingTestsFn(structure D=BenchStrict val label="strict")

functor NofibFluidMeshTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
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
 fun check name actual=let val expected=BenchApplicationTestIO.read("tests/benchmarks/data/nofib-fluid/"^name^".reference")
     in BenchApplicationTestIO.compare("nofib-fluid/"^label^"/"^name,expected,actual^"\n")end

 val header=K.input(BenchApplicationTestIO.read"tests/benchmarks/data/nofib-fluid/source/fluid.stdin")
 val(file,(mon,iterations,tolerance,jacobiIterations,jacobiTolerance,relax,time))=K.readConfig header
 val _=T.check("nofib-fluid/"^label^"/configuration",fn()=>file="runtime_files/chan8.dat"andalso not mon andalso iterations=1 andalso jacobiIterations=2
    andalso Real.==(D.force tolerance,K.R.round 1.0e~5)
    andalso Real.==(D.force jacobiTolerance,K.R.round 0.01)
    andalso Real.==(D.force relax,1.0)andalso Real.==(D.force time,K.R.round 0.01))

 val mesh:K.mesh=K.readMesh(K.input(BenchApplicationTestIO.read("tests/benchmarks/data/nofib-fluid/source/"^file)))
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
structure NeedMesh=NofibFluidMeshTestsFn(structure D=BenchNeed val label="lazy")
structure StrictMesh=NofibFluidMeshTestsFn(structure D=BenchStrict val label="strict")

functor NofibFluidFullTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchFluidFn(D)
 val source=K.input(BenchApplicationTestIO.read"tests/benchmarks/data/nofib-fluid/source/fluid.stdin")
 val(file,config as(mon,iterations,tolerance,jacobi,jacobiTolerance,relax,time))=K.readConfig source
 val mesh=K.readMesh(K.input(BenchApplicationTestIO.read("tests/benchmarks/data/nofib-fluid/source/"^file)))
 fun check(name,config)=let
      val actual=K.outputString(K.run config mesh)
      val expected=BenchApplicationTestIO.read("tests/benchmarks/data/nofib-fluid/"^name^".reference")
   in BenchApplicationTestIO.compare("nofib-fluid/"^label^"/complete/"^name,expected,actual)end

 val _=List.app check[
   ("fluid-output",config),("fluid-monitor",(true,iterations,tolerance,jacobi,jacobiTolerance,relax,time)),
   ("fluid-two-steps",(false,2,tolerance,jacobi,jacobiTolerance,relax,time)),
   ("fluid-two-steps-monitor",(true,2,tolerance,jacobi,jacobiTolerance,relax,time)),
   ("fluid-tolerance-stop",(false,10,K.number 1.0e6,jacobi,jacobiTolerance,relax,time))]
end
structure NeedFull=NofibFluidFullTestsFn(structure D=BenchNeed val label="lazy")
structure StrictFull=NofibFluidFullTestsFn(structure D=BenchStrict val label="strict")

structure FloatShowTests=struct
 structure W=Word32
 fun decode word=
   let val exponent=W.toInt(W.andb(W.>>(word,0w23),0wxFF))
       val fraction=W.toInt(W.andb(word,0wx7FFFFF))
       val value=if exponent=0 then Real.fromManExp{man=Real.fromInt fraction,exp= ~149}
         else if exponent=255 then if fraction=0 then Real.posInf else 0.0/0.0
         else Real.fromManExp{man=Real.fromInt(8388608+fraction),exp=exponent-150}
   in if W.andb(word,0wx80000000)=0w0 then value else ~value end
 val input=TextIO.openIn"tests/benchmarks/data/nofib-fluid/float-show.reference"
 fun loop n=case TextIO.inputLine input of NONE=>n|SOME line=>
   let val fields=String.tokens(fn c=>c= #"|"orelse c= #"\n")line
       val(word,expected)=case fields of[word,expected]=>
           (W.fromLargeInt(valOf(IntInf.fromString word)),expected)|_=>raise Fail"oracle row"
       val actual=BenchFluidFloatShow.show(decode word)
   in T.check("nofib-fluid/float-show/"^W.toString word,fn()=>actual=expected);loop(n+1)end

 val count=loop 0
 val _=TextIO.closeIn input
 val _=T.check("nofib-fluid/float-show/observation-count",fn()=>count=10015)
end

functor NofibFluidControlTestsFn(structure D:BENCH_SUSPEND val strict:bool val label:string)=struct
 structure K=BenchFluidFn(D)
 structure Check=BenchFluidCheckFn(K)
 exception Demanded
 val hits=ref 0
 val first=D.delay(fn()=>(hits:= !hits+1;13.0))
 val result=K.mult first K.zero
 val _=T.check("nofib-fluid/"^label^"/zero-skips-first-operand",fn()=>
   Real.==(D.force result,0.0)andalso !hits=(if strict then 1 else 0))
 val _=T.check("nofib-fluid/"^label^"/operand-sharing",fn()=>
   Real.==(D.force first,13.0)andalso Real.==(D.force first,13.0)andalso !hits=1)
 val normalized=ref 0
 val packed=K.pack(fn(value:int)=>(normalized:= !normalized+1;value=42))(fn()=>42)
 val _=T.check("nofib-fluid/"^label^"/normal-flag-deferred",fn()=> !normalized=0 andalso K.retrieve packed=42 andalso !normalized=0)
 val _=T.check("nofib-fluid/"^label^"/normal-flag-shared",fn()=>
   K.normalize packed andalso K.normalize packed andalso !normalized=1)
 val poisoned=K.pack(fn(_ :int)=>true)(fn()=>raise Demanded)
 val _=T.raises("nofib-fluid/"^label^"/object-demand",fn Demanded=>true|_=>false,fn()=>K.retrieve poisoned)
 val calls=ref 0
 fun reader chars=BenchLazy.delay(fn()=>(calls:= !calls+1;BenchLazy.force(K.readInt chars)))
 val(values,rest)=K.readN reader 2(K.input"10 20 30")
 val _=T.check("nofib-fluid/"^label^"/input-value-pass",fn()=>
   K.F.toList values=[10,20]andalso !calls=2)
 val _=T.check("nofib-fluid/"^label^"/independent-input-drop-pass",fn()=>
   K.outputString rest=" 30"andalso !calls=4)
 val _=T.check("nofib-fluid/"^label^"/zero-count-skips-files",fn()=>
   Check.run["0","missing-header-must-not-open","0"]="0")
 val _=T.check("nofib-fluid/"^label^"/negative-count-skips-files",fn()=>
   Check.run["-1","missing-header-must-not-open","0"]="0")
 val original=BenchApplicationTestIO.read"tests/benchmarks/data/nofib-fluid/fluid-output.reference"
 val expected=0wx9DCE0361F540E943:Word64.word
 val _=T.check("nofib-fluid/"^label^"/reviewed-source-hash",fn()=>K.hash(K.input original)=expected)
 val perturbed=String.str(if String.sub(original,0)= #"X"then #"Y"else #"X")^String.extract(original,1,NONE)
 val _=T.check("nofib-fluid/"^label^"/perturbed-output-hash",fn()=>K.hash(K.input perturbed)<>expected)
end
structure NeedFluidControls=NofibFluidControlTestsFn(structure D=BenchNeed val strict=false val label="lazy")
structure StrictFluidControls=NofibFluidControlTestsFn(structure D=BenchStrict val strict=true val label="strict")
