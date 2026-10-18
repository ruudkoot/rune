from pathlib import Path
import json,subprocess
p=Path(__file__).resolve().parent
rows=json.loads((p/'database.json').read_text())['records']
source=r'''functor DatabaseProbeFn(structure D:BENCH_SUSPEND val label:string)=struct
 structure K=BenchNucleic2Fn(structure D=D val shared=false)
 structure W=Word32
 fun bits x=
   let val sign=if Real.signBit x then 0wx80000000:W.word else 0w0
       val y=Real.abs x
       val payload=if Real.==(y,0.0)then 0w0
         else let val{man,exp}=Real.toManExp y
              in W.orb(W.<<(W.fromInt(exp+126),0w23),
                  W.fromInt(Real.toInt IEEEReal.TO_NEAREST(man*16777216.0)-8388608))end
   in IntInf.toString(W.toLargeInt(W.orb(sign,payload)))end
 fun array xs="["^String.concatWith","xs^"]"
 fun point p=let val K.Pt(x,y,z)=D.force p in List.map(fn x=>bits(D.force x))[x,y,z]end
 fun matrix t=let val K.Tfo(a,b,c,d,e,f,g,h,i,j,k,l)=D.force t
   in List.map(fn x=>bits(D.force x))[a,b,c,d,e,f,g,h,i,j,k,l]end
 fun specific s=case D.force s of
  K.A(a,b,c,d,e,f,g,h)=>(0,[a,b,c,d,e,f,g,h])
 |K.C(a,b,c,d,e,f)=>(1,[a,b,c,d,e,f])
 |K.G(a,b,c,d,e,f,g,h,i)=>(2,[a,b,c,d,e,f,g,h,i])
 |K.U(a,b,c,d,e)=>(3,[a,b,c,d,e])
 fun nucleotide n=
  let val K.Nuc(FIELDS)=D.force n
      val(tag,extra)=specific x
  in array[array(List.concat(List.map matrix[TRANSFORMS])),
           array(List.concat(List.map point[POINTS])),
           array[Int.toString tag,array(List.concat(List.map point extra))]]end
 val actual=array(List.map nucleotide[DATABASE])^"\n"
 val expected=let val f=TextIO.openIn"tests/out/benchmarks/nucleic2-originals/database-expected.json"
   in TextIO.inputAll f before TextIO.closeIn f end
 val _=if actual=expected then print("PASS "^label^" all database literal bits\n")
  else let val f=TextIO.openOut("tests/out/benchmarks/nucleic2-originals/database-"^label^".actual")
       in TextIO.output(f,actual);TextIO.closeOut f;raise Fail"database bits"end
end
structure NeedDatabase=DatabaseProbeFn(structure D=BenchNeed val label="need")
structure StrictDatabase=DatabaseProbeFn(structure D=BenchStrict val label="strict")
'''
trans=['t'+str(i)for i in range(4)];points=['p'+str(i)for i in range(25)]
source=source.replace('FIELDS',','.join(trans+points+['x'])).replace('TRANSFORMS',','.join(trans)).replace('POINTS',','.join(points))
source=source.replace('DATABASE',','.join('K.'+r['name'].replace("'",'Prime')for r in rows))
(p/'database-probe.sml').write_text(source)
with(p/'database-probe-build.log').open('w')as out:
 subprocess.run(['bin/rune','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml','examples/benchmarks/shared/finite-binary32.sml',str(p/'geometry-kernel.sml'),str(p/'database-probe.sml'),'-o',str(p/'database-probe.rbc')],stdout=out,stderr=subprocess.STDOUT,check=True)
# Canonical compact JSON is written from reviewed original-GHC tuples.
data=json.loads((p/'database-expected.json').read_text())
(p/'database-expected.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
with(p/'database-probe.log').open('w')as out:
 subprocess.run(['bin/runevm',str(p/'database-probe.rbc')],stdout=out,stderr=subprocess.STDOUT,check=True)
print((p/'database-probe.log').read_text())
