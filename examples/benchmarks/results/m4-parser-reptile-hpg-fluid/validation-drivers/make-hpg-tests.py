from pathlib import Path
import shutil
root=Path.cwd();p=root/'tests/out/benchmarks/nofib-hpg-originals';tests=root/'tests/benchmarks';d=tests/'data/nofib-hpg';d.mkdir(exist_ok=True)
for profile in ['smoke','normal','large']:
 for chunk in range(3):shutil.copyfile(p/(profile+'-chunk-'+str(chunk)+'.reference'),d/(profile+'-chunk-'+str(chunk)+'.reference'))
shutil.copyfile(p/'random-bits.reference',d/'random-bits.reference')
(d/'.gitattributes').write_text('# Exact original-language output and Float words.\n** -whitespace\n')
(d/'FILES').write_text('\n'.join(sorted(str(f.relative_to(root))for f in d.iterdir()if f.is_file()and f.name!='FILES'))+'\n')
s=(p/'chunks-test.sml').read_text()
a=s.index('       fun output chars=');b=s.index('\n val _=List.app test',a)
s=s[:a]+r'''       fun output chars=let
          val path="tests/benchmarks/data/nofib-hpg/"^name^"-chunk-"^Int.toString(!index)^".reference"
          val expected=BenchApplicationTestIO.read path
          val actual=K.string chars
          val _=BenchApplicationTestIO.compare("nofib-hpg/"^label^"/"^name^"/chunk-"^Int.toString(!index),expected,actual)
        in index:= !index+1 end
   in K.generate(9807,65,32975)nt dt nv dv de "Main"output;
      T.check("nofib-hpg/"^label^"/"^name^"/three-chunks",fn()=> !index=3)end
'''+s[b:]
s=s.replace('functor Chunks(D:BENCH_SUSPEND)=struct','functor NofibHpgChunksTestsFn(structure D:BENCH_SUSPEND val label:string)=struct')
s=s.replace('structure A=Chunks(BenchNeed)','structure NeedChunks=NofibHpgChunksTestsFn(structure D=BenchNeed val label="lazy")').replace('structure B=Chunks(BenchStrict)','structure StrictChunks=NofibHpgChunksTestsFn(structure D=BenchStrict val label="strict")')
s+=r'''
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
 val poison=BenchLazy.delay(fn()=>raise Demanded)
 val _=T.check("nofib-hpg/"^label^"/zero-prefix-skips-producer",fn()=>
   case D.force(K.finiteFromControl(K.C.take 0 poison))of K.F.Nil=>true|_=>false)
 val _=T.raises("nofib-hpg/"^label^"/poison-is-live",fn Demanded=>true|_=>false,fn()=>BenchLazy.force poison)
end
structure NeedRandom=NofibHpgRandomTestsFn(structure D=BenchNeed val label="lazy")
structure StrictRandom=NofibHpgRandomTestsFn(structure D=BenchStrict val label="strict")
'''
(tests/'nofib-hpg-tests.sml').write_text(s)
