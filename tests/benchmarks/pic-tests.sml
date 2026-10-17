structure NeedPic=BenchPicFn(BenchNeed)
structure NeedDriver=BenchPicDriverFn(NeedPic)
structure NeedTests=struct
structure K=NeedPic
structure Driver=NeedDriver
structure D=BenchNeed
val mode="Need"

  structure I=IntInf
  structure W=Word64
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun lines text=String.tokens(fn c=>c= #"\n")text
  fun numbers line=List.map(fn s=>valOf(Real.fromString s))(tl(String.tokens Char.isSpace line))
  fun samples rows=case rows of []=>[]
    |step::dt::phi::positions::velocities::rest=>(numbers dt@numbers phi@numbers positions@numbers velocities)::samples rest
    |_=>raise Fail "invalid PIC trace"
  fun points xs=case D.force xs of K.Nil=>[]
    |K.Cons(p,rest)=>let val K.Point(x,y)=D.force p in D.force x::D.force y::points rest end
  fun values(K.State(dt,phi,heap))=
    let val K.Mesh(n,cells)=D.force phi val(pos,vel)=D.force heap
    in D.force dt::(List.tabulate(n*n,fn i=>D.force(Array.sub(cells,i)))@points pos@points vel)end
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~10,1.0E~10)
  fun check count=
    let val rows=lines(read(Int.toString count^".trace"))
        val states=samples(List.drop(rows,2))
        fun loop(_,[])=()
          |loop(k,wanted::rest)=
            (T.check("pic/"^mode^"/state-"^Int.toString count^"-"^Int.toString k,fn()=>
                ListPair.allEq close(values(K.runState count k),wanted));
             loop(k+1,rest))
        val _=loop(0,states)
        val wanted=hd(numbers(hd rows))
        val _=T.check("pic/"^mode^"/scalar-"^Int.toString count,fn()=>close(K.run count,wanted))
        val _=T.check("pic/"^mode^"/driver-"^Int.toString count,fn()=>
          Driver.run["1",Int.toString count,Int.toString count^".dt"]=Int.toString count^":1")
    in()end
  val _=List.app check[1,2,3,18,80,300]
  fun constant n value=K.makeMesh n(fn()=>List.map(fn index=>(index,D.delay(fn()=>value)))
    (K.pairs(K.indices 0(n-1))(K.indices 0(n-1))))
  fun ofList xs=D.delay(fn()=>case xs of []=>K.Nil
    |x::rest=>K.Cons(D.delay(fn()=>x),ofList rest))
  val _=T.check("pic/"^mode^"/source-potential-argument-order",fn()=>
    close(K.get(K.potential(constant 16 2.0)(constant 16 6.0)0 1)(0,0),7.0))
  val _=T.check("pic/"^mode^"/source-top-edge-stencil",fn()=>
    let val grid=K.applyOpToMesh(fn _=>fn[_,_,hi,_,_,_]=>Real.fromInt hi|_=>raise Match)(constant 4 0.0)4
    in close(K.get grid(0,1),2.0)andalso close(K.get grid(0,0),1.0)end)
  val _=T.check("pic/"^mode^"/depth-zero-prunes-recursion",fn()=>
    close(K.get(K.vCycle(K.zeroMesh 2)(K.zeroMesh 2)2 0)(0,0),0.0))
  val _=T.check("pic/"^mode^"/source-one-wrap",fn()=>close(K.wrapped 34.0,18.0)andalso close(K.wrapped(~17.0),~1.0))
  val _=T.check("pic/"^mode^"/source-push-statistics-and-state",fn()=>
    let val point=K.Point(D.delay(fn()=>2.0),D.delay(fn()=>3.0))
        val velocity=K.Point(D.delay(fn()=>1.0),D.delay(fn()=> ~2.0))
        val heap=D.delay(fn()=>(ofList[point],ofList[velocity]))
        val result=K.pushParticle heap(constant 16 2.0,constant 16 (~4.0))(D.delay(fn()=>0.25))K.zero K.zero
        val K.Pushed(acc,vel,(pos,velocity))=D.force result
    in close(D.force acc,4.0)andalso close(D.force vel,3.0)andalso
       ListPair.allEq close(points pos,[2.375,2.25])andalso ListPair.allEq close(points velocity,[1.5,~3.0])end)
  val _=T.check("pic/"^mode^"/wrong-timestep-rejected",fn()=>((Driver.run["1","80","wrong.dt"];false)handle Fail _=>true))
  val _=T.check("pic/"^mode^"/repeat-reset",fn()=>Driver.run["2","18","18.dt"]="18:2")
  val _=T.check("pic/"^mode^"/zero-repeats",fn()=>Driver.run["0","80","80.dt"]="80:0")
  val _=T.check("pic/"^mode^"/duplicate-mesh-cell-rejected",fn()=>
    ((D.force(K.makeMesh 2(fn()=>List.map(fn index=>(index,K.zero))[(0,0),(0,1),(1,0),(0,0)]));false)handle Fail _=>true))
  val _=T.check("pic/"^mode^"/missing-mesh-cell-rejected",fn()=>
    ((D.force(K.makeMesh 2(fn()=>List.map(fn index=>(index,K.zero))[(0,0),(0,1),(1,0)]));false)handle Fail _=>true))
  val _=T.check("pic/"^mode^"/zero-particles-rejected",fn()=>((Driver.run["1","0","80.dt"];false)handle Fail _=>true))
  val _=T.check("pic/"^mode^"/hash-empty",fn()=>Driver.hash ""=0w0 andalso Driver.hashReference ""=0w0)
  fun hash line=case String.tokens Char.isSpace line of [text,wanted]=>
    T.check("pic/"^mode^"/exact-hash-"^text,fn()=>Driver.hash text=valOf(W.fromString wanted)andalso Driver.hashReference text=valOf(W.fromString wanted))
    |_=>raise Fail "invalid PIC hash fixture"
  val _=List.app hash(lines(read "hashes.data"))
end
structure StrictPic=BenchPicFn(BenchStrict)
structure StrictDriver=BenchPicDriverFn(StrictPic)
structure StrictTests=struct
structure K=StrictPic
structure Driver=StrictDriver
structure D=BenchStrict
val mode="Strict"

  structure I=IntInf
  structure W=Word64
  fun read path=let val f=TextIO.openIn path val text=TextIO.inputAll f val _=TextIO.closeIn f in text end
  fun lines text=String.tokens(fn c=>c= #"\n")text
  fun numbers line=List.map(fn s=>valOf(Real.fromString s))(tl(String.tokens Char.isSpace line))
  fun samples rows=case rows of []=>[]
    |step::dt::phi::positions::velocities::rest=>(numbers dt@numbers phi@numbers positions@numbers velocities)::samples rest
    |_=>raise Fail "invalid PIC trace"
  fun points xs=case D.force xs of K.Nil=>[]
    |K.Cons(p,rest)=>let val K.Point(x,y)=D.force p in D.force x::D.force y::points rest end
  fun values(K.State(dt,phi,heap))=
    let val K.Mesh(n,cells)=D.force phi val(pos,vel)=D.force heap
    in D.force dt::(List.tabulate(n*n,fn i=>D.force(Array.sub(cells,i)))@points pos@points vel)end
  fun close(a,b)=BenchInput.closeReal(a,b,1.0E~10,1.0E~10)
  fun check count=
    let val rows=lines(read(Int.toString count^".trace"))
        val states=samples(List.drop(rows,2))
        fun loop(_,[])=()
          |loop(k,wanted::rest)=
            (T.check("pic/"^mode^"/state-"^Int.toString count^"-"^Int.toString k,fn()=>
                ListPair.allEq close(values(K.runState count k),wanted));
             loop(k+1,rest))
        val _=loop(0,states)
        val wanted=hd(numbers(hd rows))
        val _=T.check("pic/"^mode^"/scalar-"^Int.toString count,fn()=>close(K.run count,wanted))
        val _=T.check("pic/"^mode^"/driver-"^Int.toString count,fn()=>
          Driver.run["1",Int.toString count,Int.toString count^".dt"]=Int.toString count^":1")
    in()end
  val _=List.app check[1,2,3,18,80,300]
  fun constant n value=K.makeMesh n(fn()=>List.map(fn index=>(index,D.delay(fn()=>value)))
    (K.pairs(K.indices 0(n-1))(K.indices 0(n-1))))
  fun ofList xs=D.delay(fn()=>case xs of []=>K.Nil
    |x::rest=>K.Cons(D.delay(fn()=>x),ofList rest))
  val _=T.check("pic/"^mode^"/source-potential-argument-order",fn()=>
    close(K.get(K.potential(constant 16 2.0)(constant 16 6.0)0 1)(0,0),7.0))
  val _=T.check("pic/"^mode^"/source-top-edge-stencil",fn()=>
    let val grid=K.applyOpToMesh(fn _=>fn[_,_,hi,_,_,_]=>Real.fromInt hi|_=>raise Match)(constant 4 0.0)4
    in close(K.get grid(0,1),2.0)andalso close(K.get grid(0,0),1.0)end)
  val _=T.check("pic/"^mode^"/depth-zero-prunes-recursion",fn()=>
    close(K.get(K.vCycle(K.zeroMesh 2)(K.zeroMesh 2)2 0)(0,0),0.0))
  val _=T.check("pic/"^mode^"/source-one-wrap",fn()=>close(K.wrapped 34.0,18.0)andalso close(K.wrapped(~17.0),~1.0))
  val _=T.check("pic/"^mode^"/source-push-statistics-and-state",fn()=>
    let val point=K.Point(D.delay(fn()=>2.0),D.delay(fn()=>3.0))
        val velocity=K.Point(D.delay(fn()=>1.0),D.delay(fn()=> ~2.0))
        val heap=D.delay(fn()=>(ofList[point],ofList[velocity]))
        val result=K.pushParticle heap(constant 16 2.0,constant 16 (~4.0))(D.delay(fn()=>0.25))K.zero K.zero
        val K.Pushed(acc,vel,(pos,velocity))=D.force result
    in close(D.force acc,4.0)andalso close(D.force vel,3.0)andalso
       ListPair.allEq close(points pos,[2.375,2.25])andalso ListPair.allEq close(points velocity,[1.5,~3.0])end)
  val _=T.check("pic/"^mode^"/wrong-timestep-rejected",fn()=>((Driver.run["1","80","wrong.dt"];false)handle Fail _=>true))
  val _=T.check("pic/"^mode^"/repeat-reset",fn()=>Driver.run["2","18","18.dt"]="18:2")
  val _=T.check("pic/"^mode^"/zero-repeats",fn()=>Driver.run["0","80","80.dt"]="80:0")
  val _=T.check("pic/"^mode^"/duplicate-mesh-cell-rejected",fn()=>
    ((D.force(K.makeMesh 2(fn()=>List.map(fn index=>(index,K.zero))[(0,0),(0,1),(1,0),(0,0)]));false)handle Fail _=>true))
  val _=T.check("pic/"^mode^"/missing-mesh-cell-rejected",fn()=>
    ((D.force(K.makeMesh 2(fn()=>List.map(fn index=>(index,K.zero))[(0,0),(0,1),(1,0)]));false)handle Fail _=>true))
  val _=T.check("pic/"^mode^"/zero-particles-rejected",fn()=>((Driver.run["1","0","80.dt"];false)handle Fail _=>true))
  val _=T.check("pic/"^mode^"/hash-empty",fn()=>Driver.hash ""=0w0 andalso Driver.hashReference ""=0w0)
  fun hash line=case String.tokens Char.isSpace line of [text,wanted]=>
    T.check("pic/"^mode^"/exact-hash-"^text,fn()=>Driver.hash text=valOf(W.fromString wanted)andalso Driver.hashReference text=valOf(W.fromString wanted))
    |_=>raise Fail "invalid PIC hash fixture"
  val _=List.app hash(lines(read "hashes.data"))
end

structure PicDemand =
struct
  structure K=NeedPic
  structure D=BenchNeed
  structure L=BenchLazy
  fun one value=D.delay(fn()=>K.Cons(D.delay(fn()=>value),K.empty()))
  val _=T.check("pic/lazy-fine-mesh-skips-coarse",fn()=>
    let val grid=K.fineMesh(D.delay(fn()=>raise Fail "unused coarse"))2
    in ListPair.allEq(fn(a,b)=>Real.==(a,b))
      ([K.get grid(0,0),K.get grid(0,1),K.get grid(1,0),K.get grid(1,1)],[3.0,4.0,5.0,6.0])end)
  val _=T.check("pic/strict-finite-coarse-argument-is-eager",fn()=>
    ((StrictPic.fineMesh(BenchStrict.delay(fn()=>raise Fail "eager coarse"))2;false)handle Fail _=>true))
  val _=T.check("pic/lazy-density-skips-velocity-list",fn()=>
    let val p=K.Point(D.delay(fn()=>1.25),D.delay(fn()=>2.5))
        val heap=D.delay(fn()=>(one p,D.delay(fn()=>raise Fail "unused velocities")))
        val rho=K.chargeDensity heap
    in ListPair.allEq(fn(a,b)=>Real.==(a,b))
      ([K.get rho(1,2),K.get rho(2,2),K.get rho(1,3),K.get rho(2,3)],[0.375,0.125,0.375,0.125])end)
  val _=T.check("pic/lazy-push-statistics-leave-terminal-lists-delayed",fn()=>
    let val point=K.Point(D.delay(fn()=>2.0),D.delay(fn()=>3.0))
        val velocity=K.Point(K.zero,K.zero)
        val heap=D.delay(fn()=>(one point,one velocity))
        val field=K.makeMesh 16(fn()=>List.map(fn index=>(index,K.zero))(K.pairs(K.indices 0 15)(K.indices 0 15)))
        val K.Pushed(acc,vel,(pos,velocity))=D.force(K.pushParticle heap(field,field)(D.delay(fn()=>0.1))K.zero K.zero)
        val _=D.force acc val _=D.force vel
    in (case !pos of L.Pending _=>true|_=>false)andalso(case !velocity of L.Pending _=>true|_=>false)end)
end
