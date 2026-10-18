from pathlib import Path
import math,struct,json,re
p=Path(__file__).resolve().parent
def real(bits):return struct.unpack('>d',bytes.fromhex(bits.zfill(16)))[0]
def original(n):
 rows=(p/('state-'+str(n)+'.reference')).read_text().splitlines()
 arrays={};current=None;scalar={}
 for line in rows:
  cols=line.split('\t')
  if cols[0]in ['deltat','error']:scalar[cols[0]]=real(cols[1])
  elif len(cols)==3 and cols[0].isalpha():
   current=cols[0];arrays[current]={}
  else:
   index=tuple(map(int,re.findall(r'-?\d+',cols[0])))
   arrays[current][index]=real(cols[1])
 totals=[real(line.split('\t')[1])for line in(p/('totals-'+str(n)+'.reference')).read_text().splitlines()]
 return arrays,scalar,totals
def translated(file):
 arrays={};totals=[];current=None
 for line in file.read_text().splitlines():
  cols=line.split('\t')
  if cols[0]=='T':totals.append(real(cols[1]))
  elif len(cols)==1:current=cols[0];arrays[current]={}
  else:arrays[current][tuple(map(int,cols[0].split(',')))]=real(cols[1])
 return arrays,totals
def compare(file,n):
 expected,_,totals=original(n);observed,values=translated(file)
 assert expected.keys()==observed.keys()
 checks=[('total:'+str(i),x,y)for i,(x,y)in enumerate(zip(totals,values))]
 assert len(values)==13
 for name,items in expected.items():
  assert items.keys()==observed[name].keys(),name
  checks +=[(name+str(k),x,observed[name][k])for k,x in items.items()]
 unequal=[(k,x,y,abs(x-y),abs(x-y)/max(1.0,abs(x)))for k,x,y in checks if struct.pack('>d',x)!=struct.pack('>d',y)]
 bad=[(k,x,y)for k,x,y in checks if not(math.isfinite(y)and abs(x-y)<=1e-12+1e-11*abs(x))]
 result={'file':file.name,'steps':n,'cells_and_totals':len(checks),'bit_differences':len(unequal),'max_absolute':max((r[3]for r in unequal),default=0),'max_scaled':max((r[4]for r in unequal),default=0),'outside_provisional_bounds':len(bad),'first_bad':bad[:8]}
 print(json.dumps(result),flush=True)
 if unequal:print('largest:',sorted(unequal,key=lambda r:r[4],reverse=True)[:5],flush=True)
 assert not bad
 return result
if __name__=='__main__':
 results=[compare(p/('pilot-'+mode+'.state'),1)for mode in ['need','strict']]
 (p/'pilot-comparison.json').write_text(json.dumps(results,indent=2)+'\n')
