from pathlib import Path
import json
p=Path(__file__).resolve().parent
def real(x):
 s=format(x,'.17g').replace('-','~')
 return s if'.'in s or'e'in s.lower()else s+'.0'
records=json.loads((p/'observations.json').read_text())
lines=['structure WaveTests=struct',' structure N=BenchWave4Fn(BenchNeed)',' structure E=BenchWave4Fn(BenchStrict)',' structure NC=BenchWaveCheckFn(N)',' structure EC=BenchWaveCheckFn(E)',' fun check name f=T.check("wave4main/"^name,f)']
for row in records:
 n=row['steps']
 values=[]
 for matrix in row['matrices']:
  bounds='('+','.join(map(str,matrix['bounds']))+')'
  vector='Vector.fromList['+','.join(real(x)for x in matrix['cells'])+']'
  values.append('('+bounds+','+vector+')')
 lines.append(' val expected'+str(n)+'=['+','.join(values)+']')
 for variant in ['N','E']:
  lines.append(' val _=check"source-all-matrices/'+variant+'/'+str(n)+'"(fn()=>('+variant+'C.verify('+variant+'.solve '+str(n)+')expected'+str(n)+'"'+row['sumcode']+'\\n";true))')
lines+=[''' val _=check"lazy-U-boundary-does-not-demand-neighbors"(fn()=>
 let val bad=BenchNeed.delay(fn()=>raise Fail"unneeded matrix")
 in Real.==(N.updateU bad bad bad 0 0,0.0)andalso Real.==(N.updateU bad bad bad 8 7,0.0)end)''',
''' val _=check"lazy-V-boundary-does-not-demand-neighbors"(fn()=>
 let val bad=BenchNeed.delay(fn()=>raise Fail"unneeded matrix")
 in Real.==(N.updateV bad bad bad 0 0,0.0)andalso Real.==(N.updateV bad bad bad 7 8,0.0)end)''',
''' val _=check"lazy-array-cells-are-memoized"(fn()=>
 let val calls=ref 0 val a=N.A.tabulate(fn i=>(calls:= !calls+1;i))(5,8)
     val _=N.A.sub a 7 val _=N.A.sub a 7
 in !calls=1 andalso N.A.bounds a=(5,8)end)''',
''' val _=check"strict-array-materializes-cells"(fn()=>
 let val calls=ref 0 val a=E.A.tabulate(fn i=>(calls:= !calls+1;i))(5,8)
 in !calls=4 andalso E.A.sub a 7=7 end)''',
''' val _=check"array-border-indices-retained"(fn()=>
 let val a=N.A.tabulate(fn i=>i)(5,8)val left=N.A.prepend a 4 val right=N.A.append a 9
 in N.A.bounds left=(4,8)andalso N.A.values left=[4,5,6,7,8]andalso N.A.bounds right=(5,9)andalso N.A.values right=[5,6,7,8,9]end)''',
''' val _=check"numerical-perturbation-rejected"(fn()=>not(NC.close(1.00001,1.0)))''',
''' val _=check"numerical-small-roundoff-accepted"(fn()=>NC.close(1.0+1.0E~12,1.0))''',
''' val _=check"numerical-NaN-rejected"(fn()=>not(NC.close(Real.posInf-Real.posInf,1.0)))''',
'end']
(p/'tests.sml').write_text('\n'.join(lines)+'\n')
print('Generated',len([x for x in lines if 'val _=check'in x]),'full-state/demand/checker controls')
