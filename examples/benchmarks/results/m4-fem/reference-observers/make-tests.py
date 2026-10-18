from pathlib import Path
import shutil,json
p=Path(__file__).resolve().parent;root=Path.cwd();data=p/'data';data.mkdir(exist_ok=True)
files=['data.0','data.1','data.2','fem.stdin']
integerRows={'idatabase','degrees','degree-count','diagonal'}
for file in files:
 shutil.copy(p/'source'/file,data/file)
 for suffix in ['report','reference']:shutil.copy(p/(file+'.'+suffix),data/(file+'.'+suffix))
 text=(p/(file+'.observations')).read_text();lines=[]
 for line in text.splitlines():
  parts=line.split();key=parts[0]
  values=[x.replace('-','~')for x in parts[1:]]if key in integerRows else[x.upper()for x in parts[1:]]
  lines.append(key+' '+' '.join(values))
 (data/(file+'.snapshot')).write_text('\n'.join(lines)+'\n')
ref=(p/'data.0.reference').read_text().split();u=ref.index('u');value=u+2;ref[value]=format(int(ref[value],16)^1,'x')
(data/'wrong-value.reference').write_text(' '.join(ref)+'\n')
ref=(p/'data.0.reference').read_text().split();ref[-1]='0';(data/'wrong-hash.reference').write_text(' '.join(ref)+'\n')
report=(p/'data.0.report').read_text();(data/'wrong.report').write_text('!'+report[1:])
lines=['structure FemTests=struct',' structure N=BenchFemFn(val strict=false)',' structure E=BenchFemFn(val strict=true)',' structure NS=BenchFemSnapshotFn(N)',' structure ES=BenchFemSnapshotFn(E)',' structure NC=BenchFemCheckFn(N)',' structure EC=BenchFemCheckFn(E)',' structure L=BenchLazy',' structure F=BenchFemFloat',' fun check name f=T.check("fem/"^name,f)',' fun read file=let val f=TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end',' fun split text=String.tokens(fn c=>c= #"\\n")text']
for file in files:
 for variant in ['N','E']:
  lines.append(' val '+variant.lower()+file.replace('.','_')+'=split('+variant+'S.render(read"'+file+'"))')
  expected=[line for line in (data/(file+'.snapshot')).read_text().splitlines()if line]
  for i,line in enumerate(expected):
   name=line.split()[0]
   lines.append(' val _=check"original-'+name+'/'+variant+'/'+file+'"(fn()=>List.nth('+variant.lower()+file.replace('.','_')+','+str(i)+')='+json.dumps(line)+')')
  info=next(r for r in json.loads((p/'final-reference-results.json').read_text())if r['input']==file)
  lines.append(' val _=check"complete-report-result-hash/'+variant+'/'+file+'"(fn()=>'+variant+'C.run["1","'+file+'","'+file+'.report","'+file+'.reference"]="1:'+str(info['report_bytes'])+':'+str(info['result_floats'])+'")')
for name,expression,bits in [
 ('add','F.add(F.round 0.1,F.round 0.2)','3E99999A'),('divide','F.divide(1.0,10.0)','3DCCCCCD'),
 ('sqrt','F.sqrt 2.0','3FB504F3'),('tie-even-low','F.round 1.000000059604644775390625','3F800000'),
 ('tie-even-high','F.round 1.000000178813934326171875','3F800002'),
 ('smallest-subnormal','F.round(Real.fromManExp{man=1.0,exp= ~149})','1'),
 ('underflow-tie-even','F.round(Real.fromManExp{man=1.0,exp= ~150})','0'),
 ('subnormal-tie-even','F.round(Real.fromManExp{man=3.0,exp= ~150})','2'),
 ('largest-finite','F.round(Real.fromManExp{man=16777215.0,exp=104})','7F7FFFFF'),
 ('overflow','F.round(Real.fromManExp{man=1.0,exp=128})','7F800000'),
 ('negative-zero','F.negative 0.0','80000000')]:
 lines.append(' val _=check"binary32/'+name+'"(fn()=>F.bits('+expression+')=0wx'+bits+')')
lines+=[' val _=check"negative-sqrt-NaN"(fn()=>let val x=F.sqrt(~1.0)in not(Real.==(x,x))end)']
for v in ['N','E']:
 lines+=[''' val _=check"recursive-forward-vector/'''+v+'''"(fn()=>
 let val count=ref 0
     val vector='''+v+'''.A.recursiveVec 4(fn self=>fn i=>(count:= !count+1;if i=1 then 1 else '''+v+'''.A.vecsub self(i-1)+1))
     val first='''+v+'''.A.vecsub vector 4
     val second='''+v+'''.A.vecsub vector 4
 in first=4 andalso second=4 andalso !count=4 end)''',
''' val _=check"recursive-backward-vector/'''+v+'''"(fn()=>
 let val vector='''+v+'''.A.recursiveVec 4(fn self=>fn i=>if i=4 then 1 else '''+v+'''.A.vecsub self(i+1)+1)
 in '''+v+'''.A.elements vector=[4,3,2,1]end)''',
''' val _=check"recursive-band-matrix/'''+v+'''"(fn()=>
 let val diagonal='''+v+'''.A.makevec 3(fn i=>i*(i+1)div 2)
     val matrix='''+v+'''.A.recursiveVB 3 diagonal(fn self=>fn(i,j)=>if i=j then i else '''+v+'''.A.vbsub self(i-1,j)+1)
 in List.map('''+v+'''.A.vbsub matrix)('''+v+'''.A.vbpositions 3 diagonal)=[1,2,2,3,3,3]end)''',
''' val _=check"accumulation-order/'''+v+'''"(fn()=>
 let val vector='''+v+'''.A.makevec 1(fn _=>0)
     val result='''+v+'''.A.incrvec(fn(a,b)=>a*10+b)vector[(1,L.delay(fn()=>1)),(1,L.delay(fn()=>2)),(1,L.delay(fn()=>3))]
 in '''+v+'''.A.vecsub result 1=123 end)''',
''' val _=check"array-bounds/'''+v+'''"(fn()=>
 let val vector='''+v+'''.A.makevec 2(fn i=>i)
 in (('''+v+'''.A.vecsub vector 0;false)handle Subscript=>true)end)''']
lines+=[''' val _=check"lazy-bounds-skip-cells"(fn()=>
 let val vector=N.A.makevec 3(fn _=>raise Fail"unused cell")
 in N.A.boundvec vector=3 end)''',
''' val _=check"strict-array-materialization"(fn()=>
 let val count=ref 0 val vector=E.A.makevec 3(fn i=>(count:= !count+1;i))
 in !count=3 andalso E.A.boundvec vector=3 end)''',
''' val _=check"replacement-skips-old-cell"(fn()=>
 let val vector=N.A.makevec 1(fn _=>raise Fail"overwritten value")
     val result=N.A.updvec vector[(1,L.delay(fn()=>7))]
 in N.A.vecsub result 1=7 end)''']
for label,args in [('wrong-value',['data.0.report','wrong-value.reference']),('wrong-hash',['data.0.report','wrong-hash.reference']),('wrong-report',['wrong.report','data.0.reference'])]:
 lines.append(' val _=check"reject-'+label+'"(fn()=>((NC.run["1","data.0","'+args[0]+'","'+args[1]+'"];false)handle Fail text=>String.isPrefix"incorrect result:"text))')
lines.append(' val _=check"zero-repetitions"(fn()=>NC.run["0","data.0","data.0.report","data.0.reference"]="0:0:0")')
lines+=['end']
(p/'tests.sml').write_text('\n'.join(lines)+'\n')
base=['tests/basis/harness.sml','examples/benchmarks/shared/input.sml','examples/benchmarks/shared/lazy.sml','examples/benchmarks/shared/suspend.sml','examples/benchmarks/shared/hartel-ida-finite.sml','examples/benchmarks/shared/nofib-linear-float.sml']+[str(p/(x+'.sml'))for x in ['float','arrays','kernel','snapshot','report','check','tests']]+['tests/basis/finish.sml']
(p/'sources.txt').write_text(''.join(str(root/x)+'\n'for x in base))
(p/'data-list').write_text(''.join(f.name+'\n'for f in sorted(data.iterdir())if f.is_file()))
print('Generated',sum('val _=check'in x for x in lines),'state/numeric/report/demand assertions')
