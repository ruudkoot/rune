from pathlib import Path
p=Path(__file__).resolve().parent
s=r'''functor LinearTestsFn(P:sig structure D:BENCH_SUSPEND val policy:string end)=
struct
  structure K=BenchLinearFn(P.D)
  structure B=K.B
  structure S=BenchStream
  structure L=BenchLazy
  structure Driver=BenchLinearDriverFn(struct type number=K.number val stats=K.stats val value=B.value end)
  val base="PRIVATE/"
  fun label s="linear/"^P.policy^"/"^s
  fun read name=Driver.read(base^name)
  fun scalar text=BenchLinearFloat.round(valOf(Real.fromString text))
  fun values vector=List.rev(S.foldl(fn(x,xs)=>B.value x::xs)[]vector)
  fun block matrix=List.rev(S.foldl(fn(row,rows)=>values row::rows)[]matrix)
  fun flat matrix=List.concat(block matrix)
  fun same(a,b)=ListPair.allEq Real.==(a,b)
  val source=String.tokens(fn c=>c= #"\n")(read"math.reference")
  val a=K.input 2 val soln=K.solution 2 val b=K.mvmult a soln
  val(scaled,rhs)=K.scale a b
  val _=List.app(fn line=>case String.tokens Char.isSpace line of
      "inverse"::rest=>T.check(label"source-block-inverse",fn()=>same(flat(B.inverse(K.at 0 0 a)),List.map scalar rest))
    |"scaled"::r::c::rest=>T.check(label("source-scaled-"^r^"-"^c),fn()=>
       same(flat(K.at(BenchInput.integer r)(BenchInput.integer c)scaled),List.map scalar rest))
    |"precondition"::rest=>T.check(label"source-precondition",fn()=>
       same(List.concat(List.rev(S.foldl(fn(v,vs)=>values v::vs)[](K.precondition 0 scaled rhs))),List.map scalar rest))
    |"well"::rest=>T.check(label"source-mixed-dimension-well",fn()=>
       let val unit=B.identity 4
           val m=S.fromList[
             S.fromList[K.E(0,0,unit),K.E(0,1,B.block[[0.1],[0.2],[0.3],[0.4]])],
             S.fromList[K.E(1,0,B.block[[0.1,0.2,0.3,0.4]]),K.E(1,1,B.block[[2.0]])]]
           val v=S.fromList[B.vec[1.0,2.0,3.0,4.0],B.vec[5.0]]
       in same(List.concat(List.rev(S.foldl(fn(v,vs)=>values v::vs)[](K.precondition 1 m v))),List.map scalar rest)end)
    |_=>raise Fail "bad original linear math record")source
  val _=List.app(fn(n,limit,file)=>T.check(label("source-metrics-"^Int.toString n^"-"^Int.toString limit),fn()=>
    let val wanted=Driver.reference(read file)
        val(text,count)=Driver.consume wanted(K.stats n limit)
    in count=List.length wanted andalso String.size text=count*63 end))
    [(2,10,"real-smoke.metrics"),(2,50,"gc-smoke.metrics"),(3,10,"small3.metrics")]
  val _=T.check(label"source-gc-driver",fn()=>Driver.run"gc"["1","2","50",base^"gc-smoke.metrics"]="1:5:400")
  val _=T.check(label"source-real-driver",fn()=>Driver.run"real"["1","2","10",base^"real-smoke.metrics"]="1:5:400")
  val _=T.check(label"zero-repetitions",fn()=>Driver.run"real"["0","2","10",base^"real-smoke.metrics"]="0:0:0")
  val _=T.check(label"source-hash-abc",fn()=>Driver.checksum"abc"=0w96354 andalso Driver.reverseChecksum"abc"=0w96354)
  val _=T.check(label"unused-preconditioner-stays-delayed",fn()=>
    let val zero=S.map(fn v=>B.smul B.zero v)(K.solution 2)
        val states=K.iterations(fn a=>fn b=>(a,b))(fn _=>raise Fail "unused conditioner")(K.input 2)zero
    in case S.head states of K.State(_,r,_,_,count)=>count=0 andalso Real.==(B.value(K.norm r),0.0)end)
  val _=T.check(label"initial-counter-skips-scaling",fn()=>
    case S.head(K.iterations(fn _=>fn _=>raise Fail "unused scaling")
         (fn _=>raise Fail "unused conditioner")(K.input 2)(K.solution 2))of K.State(_,_,_,_,count)=>count=0)
  val _=T.check(label"inverse-times-block-near-identity",fn()=>
    let val product=block(B.mmult(B.inverse(K.at 0 0 a))(K.at 0 0 a))
    in ListPair.allEq(fn(i,row)=>ListPair.allEq(fn(j,x)=>
       BenchInput.closeReal(x,if i=j then 1.0 else 0.0,2.0E~6,0.0))
      (List.tabulate(4,fn j=>j),row))(List.tabulate(4,fn i=>i),product)end)
  val _=T.check(label"changed-metric-rejected",fn()=>
    ((Driver.consume[(0,15.0,0.0)](K.stats 2 10);false)handle Fail _=>true))
  val _=T.check(label"short-metrics-rejected",fn()=>((Driver.consume[](K.stats 2 10);false)handle Fail _=>true))
  val _=T.check(label"numeric-format-roundtrip",fn()=>
    Real.==(scalar(Driver.number(BenchLinearFloat.round 0.1)),BenchLinearFloat.round 0.1))
end
structure NeedTests=LinearTestsFn(struct structure D=BenchNeed val policy="lazy"end)
structure StrictTests=LinearTestsFn(struct structure D=BenchStrict val policy="strict"end)
structure LinearFloatTests=struct
  structure F=BenchLinearFloat
  val half=Real.fromManExp{man=1.0,exp= ~24}
  val _=T.check("linear/float/tie-to-even-down",fn()=>Real.==(F.round(1.0+half),1.0))
  val _=T.check("linear/float/tie-to-even-up",fn()=>Real.==(F.round(1.0+3.0*half),1.0+4.0*half))
  val tiny=Real.fromManExp{man=1.0,exp= ~149}
  val _=T.check("linear/float/subnormal-even-zero",fn()=>Real.==(F.round(tiny/2.0),0.0))
  val _=T.check("linear/float/subnormal-even-two",fn()=>Real.==(F.round(1.5*tiny),2.0*tiny))
  val _=T.check("linear/float/overflow",fn()=>not(Real.isFinite(F.round(Real.fromManExp{man=1.0,exp=128}))))
end
'''
(p/'tests.sml').write_text(s.replace('PRIVATE',str(p)))
