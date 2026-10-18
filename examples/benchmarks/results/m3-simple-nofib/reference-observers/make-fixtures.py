from pathlib import Path
import re,struct,json
p=Path(__file__).resolve().parent;d=p/'data';d.mkdir(exist_ok=True)
records=[]
for grid,stepslist,prefix in [(100,[0,1,2,5,20,100],''),(8,[0,1,2,5],'small-')]:
 for steps in stepslist:
  totals=[line.split('\t')[1].zfill(16)for line in(p/(prefix+'totals-'+str(steps)+'.reference')).read_text().splitlines()]
  assert len(totals)==13
  (d/('totals-'+str(grid)+'-'+str(steps)+'.reference')).write_text('SIMPLE-TOTALS '+str(grid)+' '+str(steps)+' 13\n'+'\n'.join(totals)+'\n')
  rows=(p/(prefix+'state-'+str(steps)+'.reference')).read_text().splitlines()
  out=['SIMPLE-STATE '+str(grid)+' '+str(steps)+' 11']
  cells=0
  for line in rows:
   cols=line.split('\t')
   if cols[0]in['deltat','error']:out.append(cols[0]+' '+cols[1].zfill(16))
   elif cols[0].startswith('('):
    i,j=map(int,re.findall(r'\d+',cols[0]));out.append(str(i)+' '+str(j)+' '+cols[1].zfill(16));cells+=1
   else:
    a,b,c,e=map(int,re.findall(r'\d+',cols[1]));assert (c-a+1)*(e-b+1)==int(cols[2])
    out.append(cols[0]+' '+str(a)+' '+str(b)+' '+str(c)+' '+str(e)+' '+cols[2])
  (d/('state-'+str(grid)+'-'+str(steps)+'.reference')).write_text('\n'.join(out)+'\n')
  records.append(dict(grid=grid,steps=steps,cells=cells,totals=13))
# Deliberate values outside both tolerance components, plus nonfinite inputs.
(d/'wrong-totals.reference').write_text('SIMPLE-TOTALS 8 1 13\n'+'\n'.join(['3ff0000000000000']*13)+'\n')
(p/'fixture-counts.json').write_text(json.dumps(records,indent=2)+'\n')
