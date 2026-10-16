from pathlib import Path
import json,ast,shutil
p=Path(__file__).resolve().parent;cases=json.loads((p/'small-cases.json').read_text());shutil.copy(p/'runtime_files/inverter.in',p/'inverter.in')
rows=[]
for row in cases:
 args=row['args'][:];args[0]=Path(args[0]).name
 labels=ast.literal_eval((p/args[-1]).read_text().splitlines()[0]);rows.append((row['name'],args,row['rows'],row['rows']*len(labels)))
(p/'cases.sml').write_text('structure ScsCases =\nstruct\n  val values = ['+','.join('('+json.dumps(name)+',['+','.join(json.dumps(x)for x in args)+'],'+str(count)+','+str(points)+')'for name,args,count,points in rows)+']\nend\n')
source=p/'inverter-small.exacttrace';lines=source.read_text().splitlines(True);data=lines[1];n,d,vector=data.split(' ',2);values=ast.literal_eval(vector)
for name in ['wrong-header','wrong-time','wrong-value','nonfinite','wrong-dimension','truncated','extra']:
 modified=lines[:]
 if name=='wrong-header':modified[0]=modified[0].replace('i:Plus','i:Other')
 elif name=='wrong-time':modified[1]='1 1000000000000 '+vector
 elif name=='wrong-value':
  changed=values[:];changed[0]+=4*(1e-24+1e-11*abs(changed[0]));modified[1]=n+' '+d+' '+repr(changed)+'\n'
 elif name=='nonfinite':modified[1]=n+' '+d+' [NaN,'+','.join(repr(v)for v in values[1:])+']\n'
 elif name=='wrong-dimension':modified[1]=n+' '+d+' '+repr(values[:-1])+'\n'
 elif name=='truncated':modified=modified[:-1]
 else:modified.append('0 1 []\n')
 (p/(name+'.exacttrace')).write_text(''.join(modified))
(p/'test-data.txt').write_text(''.join(name+'\n'for name in ['inverter.in','rc.in','rl.in','gi.in','normal.prepare','rational-bits.data','random-vectors.data']+[row[1][-1]for row in rows]+[name+'.exacttrace'for name in ['wrong-header','wrong-time','wrong-value','nonfinite','wrong-dimension','truncated','extra']]))
# Separate the portable bit encoder from the earlier standalone test driver.
text=(p/'rational-tests.sml').read_text();a=text.index('  fun bitPattern');b=text.index('  fun line',a)
(p/'bits.sml').write_text('structure BenchScsDoubleBits =\nstruct\n  structure Q=BenchScsRational\n  structure I=IntInf\n'+text[a:b]+'end\n')
