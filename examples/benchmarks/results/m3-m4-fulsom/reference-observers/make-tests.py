from pathlib import Path
import re,json
p=Path(__file__).resolve().parent
def real(text):
 text=str(text).replace('-','~')
 return text if'.'in text or'e'in text.lower()else text+'.0'
intervals=[('point','0.0'),('point','2.0'),('range','~2.0','3.0'),('range','1.0','4.0'),('range','~5.0','~1.0')]
lines=['structure FulsomTests=struct',' structure N=BenchFulsomFn(BenchNeed)',' structure E=BenchFulsomFn(BenchStrict)',' structure L=BenchLazy',' structure S=BenchStream',' structure D=BenchNeed',' structure NC=BenchFulsomCheckFn(N)',' structure EC=BenchFulsomCheckFn(E)',' fun check name f=T.check("fulsom/"^name,f)']
for variant in ['N','E']:
 lines.append(' val '+variant.lower()+'Intervals=['+','.join(variant+'.I.'+spec[0]+'('+spec[1]+')'+('('+spec[2]+')'if len(spec)>2 else'')for spec in intervals)+']')
 lines.append(' fun '+variant.lower()+'Interval value wanted=case '+('BenchNeed'if variant=='N'else'BenchStrict')+'.force value of '+variant+'.I.Point x=>(case wanted of[a]=>Real.==('+('BenchNeed'if variant=='N'else'BenchStrict')+'.force x,a)|_=>false)|'+variant+'.I.Range(a,b)=>(case wanted of[x,y]=>Real.==('+('BenchNeed'if variant=='N'else'BenchStrict')+'.force a,x)andalso Real.==('+('BenchNeed'if variant=='N'else'BenchStrict')+'.force b,y)|_=>false)')
for idx,row in enumerate((p/'interval-observations.reference').read_text().splitlines()):
 fields=row.split()
 if fields[0]in ['add','min']:
  operation,i,j,kind,*vals=fields
  for variant in ['N','E']:
   call=variant+'.I.'+('add'if operation=='add'else'minimum')+'(List.nth('+variant.lower()+'Intervals,'+i+'))(List.nth('+variant.lower()+'Intervals,'+j+'))'
   lines.append(' val _=check"original-'+operation+'/'+variant+'/'+i+'/'+j+'"(fn()=>'+variant.lower()+'Interval('+call+')['+','.join(real(x)for x in vals)+'])')
 elif fields[0]=='compare':
  _,i,j,*wanted=fields
  for variant in ['N','E']:
   args='(List.nth('+variant.lower()+'Intervals,'+i+'))(List.nth('+variant.lower()+'Intervals,'+j+'))'
   comparisons=[variant+'.I.'+f+args for f in ['less','greater','lessEqual','greaterEqual']]
   lines.append(' val _=check"original-compare/'+variant+'/'+i+'/'+j+'"(fn()=>['+','.join(comparisons)+']=['+','.join(x.lower()for x in wanted)+'])')
 elif fields[0]=='square':
  _,i,kind,*vals=fields
  for variant in ['N','E']:lines.append(' val _=check"original-square/'+variant+'/'+i+'"(fn()=>'+variant.lower()+'Interval('+variant+'.I.square(List.nth('+variant.lower()+'Intervals,'+i+')))['+','.join(real(x)for x in vals)+'])')
for row in json.loads((p/'raw-reference-results.json').read_text()):
 depth=row['depth'];h=row['signed64_hash'];size=row['bytes']
 for variant in ['N','E']:
  lines.append(' val _=check"original-raster-and-hash/'+variant+'/'+str(depth)+'"(fn()=>'+variant+'C.runHashed["1","'+str(depth)+'","depth-'+str(depth)+'.hex","'+str(h)+'"]="1:'+str(size)+'")')
lines+=[''' val _=check"opaque-front-quad-skips-hidden-octree"(fn()=>
 let val hidden=L.delay(fn()=>raise Fail"hidden octree")
     val front=L.delay(fn()=>N.QFull N.white)
 in case L.force(N.qo hidden front)of N.QFull _=>true|_=>false end)''',
''' val _=check"false-change-keeps-dead-residual-undemanded"(fn()=>
 let val shape=L.delay(fn()=>N.Function(fn rgb=>fn _=>L.delay(fn()=>N.Result(N.I.point 1.0,L.delay(fn()=>raise Fail"dead csg"),rgb,L.delay(fn()=>false)))))
     val result=N.calc shape N.white(N.I.point 0.0,N.I.point 0.0,N.I.point 0.0)
 in N.I.greater(N.answer result)(N.I.point 0.0)andalso not(N.changed result)end)''',
''' val _=check"outside-octree-skips-lighting"(fn()=>
 let val shape=L.delay(fn()=>N.Function(fn rgb=>fn _=>L.delay(fn()=>N.Result(N.I.point 1.0,L.delay(fn()=>raise Fail"dead csg"),D.delay(fn()=>raise Fail"unused color"),L.delay(fn()=>false)))))
 in case L.force(N.octer 1 shape(N.I.range(~2.0)2.0,N.I.range(~2.0)2.0,N.I.range(~2.0)2.0))of N.OEmpty=>true|_=>false end)''',
''' val _=check"interval-upper-comparison-skips-lower-bound"(fn()=>
 let val value=D.delay(fn()=>N.I.Range(D.delay(fn()=>raise Fail"unused lower"),D.delay(fn()=> ~1.0)))
 in N.I.less value(N.I.point 0.0)end)''',
''' val _=check"raster-prefix-keeps-color-components-pending"(fn()=>
 let val color=D.delay(fn()=>raise Fail"unused color")
     val words=N.tileWords 1 2 4 color(S.empty())
 in S.take 3 words=[1,2,4]end)''',
''' val _=check"exact-byte-validator-rejects-wrong-raster"(fn()=>((NC.consume 0"00000000";false)handle Fail why=>String.isPrefix"incorrect result:"why))''',
''' val _=check"signed64-modular-hash-boundary"(fn()=>NC.signed 0wxFFFFFFFFFFFFFFFF=IntInf.fromInt(~1))''',
'end']
(p/'tests.sml').write_text('\n'.join(lines)+'\n')
data=p/'data';data.mkdir(exist_ok=True)
import shutil
for row in json.loads((p/'raw-reference-results.json').read_text()):shutil.copy(p/('depth-'+str(row['depth'])+'.hex'),data)
(p/'data-list').write_text('\n'.join(f.name for f in sorted(data.iterdir()))+'\n')
print('Generated',sum('val _=check'in x for x in lines),'original/independent/demand assertions')
