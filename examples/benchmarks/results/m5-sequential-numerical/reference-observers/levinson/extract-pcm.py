from pathlib import Path
from decimal import Decimal
import re,struct,hashlib,json
ref=Path(__file__).resolve().parent
source=(ref/'levinson_durbin_dataset.ml').read_text();records={}
for label,body in re.findall(r'let ([aiueo]) = \[\|(.*?)\|\]',source,re.S):
 values=[Decimal(x.strip())for x in body.split(';')if x.strip()];samples=[]
 for value in values:
  scaled=value*32768;assert scaled==scaled.to_integral_value();sample=int(scaled)
  assert -32768<=sample<=32767 and struct.pack('>d',float(value))==struct.pack('>d',sample/32768)
  samples.append(sample)
 target=ref/(label+'.pcm');data=str(len(samples))+'\n'+'\n'.join(str(x).replace('-','~')for x in samples)+'\n'
 if target.exists():assert target.read_text()==data
 else:target.write_text(data)
 records[label]={'samples':len(samples),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
assert set(records)==set('aiueo')and sum(row['samples']for row in records.values())==14149
(ref/'pcm-verification.json').write_text(json.dumps(records,indent=2)+'\n')
print('PASS every signed16 sample conversion, count and IEEE64 identity')
