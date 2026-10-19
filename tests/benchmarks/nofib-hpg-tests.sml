functor NofibHpgChunksTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchHpgFn(D)
 fun test(name,nt,dt,nv,dv,de)=
   let val index=ref 0
       fun output chars=let
          val path="tests/benchmarks/data/nofib-hpg/"^name^"-chunk-"^Int.toString(!index)^".reference"
          val expected=BenchApplicationTestIO.read path
          val actual=K.string chars
          val _=BenchApplicationTestIO.compare("nofib-hpg/"^label^"/"^name^"/chunk-"^Int.toString(!index),expected,actual)
        in index:= !index+1 end
   in K.generate(9807,65,32975)nt dt nv dv de "Main"output;
      T.check("nofib-hpg/"^label^"/"^name^"/three-chunks",fn()=> !index=3)end

 val _=List.app test[("smoke",8,4,10,6,6),("normal",40,5,60,6,6),("large",80,8,100,8,8)]
end
structure NeedChunks=NofibHpgChunksTestsFn(structure D=BenchNeed val label="lazy")
structure StrictChunks=NofibHpgChunksTestsFn(structure D=BenchStrict val label="strict")

functor NofibHpgRandomTestsFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure R=BenchHpgRandomFn(D)
 structure K=BenchHpgFn(D)
 structure W=Word32
 fun bits r=if Real.==(r,0.0)then 0w0 else
   let val{man,exp}=Real.toManExp r
       val m=Real.round(man*16777216.0)
   in W.orb(W.<<(W.fromInt(exp+126),0w23),W.fromInt(m-8388608))end
 val input=TextIO.openIn"tests/benchmarks/data/nofib-hpg/random-bits.reference"
 fun loop 0 values=()
   |loop n values=case BenchLazy.force values of R.C.Nil=>raise Fail"source RNG EOF"
    |R.C.Cons(x,rest)=>let
       val expected=case TextIO.inputLine input of SOME s=>W.fromLargeInt(valOf(IntInf.fromString s))
         |NONE=>raise Fail"original RNG EOF"
       val actual=bits(D.force(BenchLazy.force x))
     in T.check("nofib-hpg/"^label^"/random-"^Int.toString(10000-n),fn()=>actual=expected);
        loop(n-1)rest end
 val _=loop 10000(R.random(9807,65,32975))
 val _=TextIO.closeIn input
 exception Demanded
 val chosen=ref 0
 val e1=K.makeEnv(9807,65,32975)(fn _=>())
 val e2=K.makeEnv(9807,65,32975)(fn _=>())
 val K.Env(_,cs1,ts1,vs1,_,_,_,_)=e1
 val K.Env(_,cs2,ts2,vs2,_,_,_,_)=e2
 val _=T.check("nofib-hpg/"^label^"/global-name-stream-sharing",fn()=>cs1=cs2 andalso ts1=ts2 andalso vs1=vs2)
 val _=K.chooseCont[fn()=>fn _=>(chosen:= !chosen+1),fn()=>raise Demanded]e1
 val _=T.check("nofib-hpg/"^label^"/unselected-continuation",fn()=> !chosen=1)
 val poison:int D.t K.C.seq=BenchLazy.delay(fn()=>raise Demanded)
 val _=T.check("nofib-hpg/"^label^"/zero-prefix-skips-producer",fn()=>
   case D.force(K.finiteFromControl(K.C.take 0 poison))of K.F.Nil=>true|_=>false)
 val _=T.raises("nofib-hpg/"^label^"/poison-is-live",fn Demanded=>true|_=>false,fn()=>BenchLazy.force poison)
end
structure NeedRandom=NofibHpgRandomTestsFn(structure D=BenchNeed val label="lazy")
structure StrictRandom=NofibHpgRandomTestsFn(structure D=BenchStrict val label="strict")
