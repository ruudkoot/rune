from pathlib import Path
p=Path(__file__).resolve().parent
body=r'''
structure KernelPOLICY=BenchGamtebFn(BenchPOLICY)
structure DriverPOLICY=BenchGamtebDriverFn(KernelPOLICY)
structure TestsPOLICY=struct
  structure K=KernelPOLICY
  structure M=K.M
  structure D=BenchPOLICY
  structure Driver=DriverPOLICY
  structure S=BenchStream
  structure L=BenchLazy
  val base="BASE/"
  fun read file=Driver.read(base^file)
  fun label s="gamteb/POLICY/"^s
  fun n value=M.literal value
  fun actualPoint(a,b,c)=[D.force a,D.force b,D.force c]
  val _=List.app(fn size=>
    let val path=Int.toString size^".reference"
        val wanted=Driver.reference(read path)
        val count=List.length(#results wanted)
    in T.check(label("primary-driver-"^Int.toString size),fn()=>
      Driver.run["1",Int.toString size,base^path]="1:"^Int.toString count)end)[1,2,3,10,100,1000,5000]
  fun math row=
    let val halves=String.fields(fn c=>c= #"|")row
        val(prefix,expected)=case halves of[a,b]=>(String.tokens Char.isSpace a,
          List.map Driver.real(String.tokens Char.isSpace b))|_=>raise Fail "bad math oracle"
        val(kind,args)=case prefix of name::args=>(name,List.map Driver.real args)|_=>raise Fail "bad math arguments"
        val observed=case(kind,args)of
            ("random",[seed])=>let val(a,b)=M.random(n seed)in[D.force a,D.force b]end
          |("distance",[x,y,z,u,v,w])=>let val(distance,surface)=M.distance(n x,n y,n z)(n u,n v,n w)
            in[D.force distance,Real.fromInt surface]end
          |("isotropic",[seed])=>actualPoint(M.isotropic(n seed))
          |("rotate",[u,v,w,angle,seed])=>actualPoint(M.rotate(n u,n v,n w)(n angle)(n seed))
          |("klein",[energy,r])=>[D.force(M.klein(n energy)(n r))]
          |("xsect",[energy])=>let val(index,prob)=K.xsect(n energy)
                val(a,b,c,t)=L.force prob
            in[Real.fromInt(L.force index),D.force a,D.force b,D.force c,D.force t]end
          |_=>raise Fail "unknown math oracle operation"
        val absolute=if kind="xsect"then 1.0E~15 else 1.0E~12
    in T.check(label("math-"^String.concatWith "-"prefix),fn()=>
      ListPair.allEq(fn(a,b)=>BenchInput.closeReal(a,b,absolute,1.0E~11))(observed,expected))end
  val _=List.app math(String.tokens(fn c=>c= #"\n")(read"math.references"))
  val wanted=Driver.reference(read"1.reference")
  fun reference particles tables results stats cells:Driver.reference=
    {particles=particles,tables=tables,results=results,stats=stats,cells=cells}
  fun same tables results stats cells=reference(#particles wanted)tables results stats cells
  fun unchanged results stats cells=same(#tables wanted)results stats cells
  fun reject labelName wrong=T.check(label labelName,fn()=>
    ((Driver.checked 1 wrong;false)handle Fail _=>true))
  fun update at change values=
    let fun loop _ []=[]|loop i(value::rest)=(if i=at then change value else value)::loop(i+1)rest
    in loop 0 values end
  val _=reject "wrong-particle-count"(reference 2(#tables wanted)(#results wanted)(#stats wanted)(#cells wanted))
  val _=List.app(fn i=>reject("wrong-prefix-table-"^Int.toString i)
    (same(update i(fn x=>x+1.0)(#tables wanted))(#results wanted)(#stats wanted)(#cells wanted)))
    [0,1,2,3]
  val _=List.app(fn i=>reject("wrong-result-weight-"^Int.toString i)
    (unchanged(update i(fn(k,j,w)=>(k,j,w+0.001))(#results wanted))(#stats wanted)(#cells wanted)))
    (List.tabulate(List.length(#results wanted),fn i=>i))
  val _=reject "wrong-result-kind"(unchanged(update 0(fn(k,j,w)=>(k+1,j,w))(#results wanted))(#stats wanted)(#cells wanted))
  val _=reject "wrong-result-energy-index"(unchanged(update 0(fn(k,j,w)=>(k,j+1,w))(#results wanted))(#stats wanted)(#cells wanted))
  val _=reject "missing-result"(unchanged(tl(#results wanted))(#stats wanted)(#cells wanted))
  val _=reject "extra-result"(unchanged(#results wanted@[hd(#results wanted)])(#stats wanted)(#cells wanted))
  val _=List.app(fn i=>reject("wrong-statistic-"^Int.toString i)
    (unchanged(#results wanted)(update i(fn x=>x+0.001)(#stats wanted))(#cells wanted)))
    (List.tabulate(12,fn i=>i))
  val _=List.app(fn i=>reject("wrong-accumulated-cell-"^Int.toString i)
    (unchanged(#results wanted)(#stats wanted)(update i(fn x=>x+0.001)(#cells wanted))))
    (List.tabulate(105,fn i=>i))
  val _=T.check(label"small-interior-bound-is-accepted",fn()=>
    let val results=update 0(fn(k,j,w)=>(k,j,w+1.0E~12))(#results wanted)
    in Driver.checked 1(unchanged results(#stats wanted)(#cells wanted))=2 end)
  val _=T.check(label"zero-accumulation-remains-exact",fn()=>not(Driver.accumulatedClose(1.0E~20,0.0)))
  val _=T.check(label"NaN-is-rejected",fn()=>not(Driver.close(0.0/0.0,0.0)))
  val _=T.check(label"infinity-is-rejected",fn()=>not(Driver.close(1.0/0.0,0.0)))
  val _=T.check(label"GEN17-negative-zero-roundtrip",fn()=>
    case Real.fromString(Driver.number(~0.0))of SOME x=>Real.signBit x|_=>false)
  val _=List.app(fn(text,expected)=>T.check(label("golden-hash-"^text),fn()=>
    Driver.hash text=Word64.fromInt expected andalso Driver.reverseHash text=Word64.fromInt expected))
    [("",0),("a",97),("abc",96354)]
  val _=T.check(label"hash-wraps-modulo64",fn()=>
    let val text="abcdefghijklmnopqrstuvwxyz012345678901234567890123456789"
    in Driver.hash text=Driver.reverseHash text end)
  val _=T.check(label"source-nonpositive-count-still-creates-one-source",fn()=>
    let val task=K.run 0 val actual=List.map K.resultValue(S.take 10(K.first task))
        val task1=K.run 1 val expected=List.map K.resultValue(S.take 10(K.first task1))
    in ListPair.allEq(fn((a,b,c),(x,y,z))=>a=x andalso b=y andalso Real.==(c,z))(actual,expected)end)
  val _=T.check(label"source-isotropic-invalid-seed-demands-cycle",fn()=>
    ((actualPoint(M.isotropic(n 5.1));false)handle Fail _=>true))
  val _=T.check(label"source-tie-chooses-fourth-surface",fn()=>
    let val(_,surface)=M.distance(n 0.0,n 0.0,n 0.0)(n 0.0,n 0.0,n 0.0)in surface=4 end)
  val _=T.check(label"source-internal-plane-is-twenty",fn()=>
    let val(d,surface)=M.distance(n 0.0,n 0.0,n 0.0)(n 0.0,n 1.0,n 0.0)
    in surface=3 andalso Real.==(D.force d,20.0000001)end)
  val _=T.check(label"source-cylLen2-is-thirty",fn()=>
    let val(d,surface)=M.distance(n 0.0,n 25.0,n 0.0)(n 0.0,n(~1.0),n 0.0)
    in surface=4 andalso Real.==(D.force d,~4.9999999)end)
  val _=T.check(label"source-isotropic-vector-is-not-normalized",fn()=>
    let val[a,b,c]=actualPoint(M.isotropic(n 0.5))
    in a*a+b*b+c*c>1.5 end)
  val _=T.check(label"source-rotas-pole-guard-leaves-unused-division",fn()=>
    List.all Real.isFinite(actualPoint(M.rotate(n 0.0,n 0.0,n 1.0)(n 0.25)(n 0.5))))
  val _=T.check(label"driver-repeat-reset",fn()=>Driver.run["2","1",base^"1.reference"]="2:4")
  val _=T.check(label"driver-zero-repeats",fn()=>Driver.run["0","1",base^"1.reference"]="0:0")
  val _=List.app(fn arg=>T.check(label("reject-particle-argument-"^arg),fn()=>
    ((Driver.run["1",arg,base^"1.reference"];false)handle Fail _=>true)))["0","-1","5001"]
  val _=T.check(label"empty-reference-rejected",fn()=>((Driver.reference"";false)handle Fail _=>true))
end
'''
s=''.join(body.replace('POLICY',policy).replace('BASE',str(p))for policy in ['Need','Strict'])
s+=r'''
structure DemandTests=struct
  structure K=KernelNeed
  structure Q=KernelStrict
  structure L=BenchLazy
  structure S=BenchStream
  val _=T.check("gamteb/lazy-terminal-position-remains-unused",fn()=>
    let val calls=ref 0
        val pos=L.delay(fn()=>(calls:= !calls+1;(K.literal 0.0,K.literal 0.0,K.literal 0.0)))
        val dir=L.delay(fn()=>(K.literal 0.0,K.literal 1.0,K.literal 0.0))
        val particle=K.particle pos dir(K.literal 1.0)(K.literal 6.0)(L.delay(fn()=>1))1(K.literal 0.5)
        val task=K.noCollision particle(L.delay(fn()=>raise Fail "unused probabilities"))1
        val _=K.resultValue(S.head(K.first task))
    in !calls=0 end)
  val _=T.check("gamteb/strict-terminal-position-is-constructed",fn()=>
    let val calls=ref 0
        val pos=L.delay(fn()=>(calls:= !calls+1;(Q.literal 0.0,Q.literal 0.0,Q.literal 0.0)))
        val dir=L.delay(fn()=>(Q.literal 0.0,Q.literal 1.0,Q.literal 0.0))
        val particle=Q.particle pos dir(Q.literal 1.0)(Q.literal 6.0)(L.delay(fn()=>1))1(Q.literal 0.5)
        val task=Q.noCollision particle(L.delay(fn()=>raise Fail "unused probabilities"))1
        val _=Q.resultValue(S.head(Q.first task))
    in !calls=1 end)
  val _=T.check("gamteb/lazy-seed-is-shared-between-random-outputs",fn()=>
    let val calls=ref 0
        val seed=BenchNeed.delay(fn()=>(calls:= !calls+1;0.5))
        val(a,b)=K.random seed val delayed= !calls=0
        val _=BenchNeed.force a val _=BenchNeed.force b
    in delayed andalso !calls=1 end)
end
'''
(p/'tests.sml').write_text(s)
