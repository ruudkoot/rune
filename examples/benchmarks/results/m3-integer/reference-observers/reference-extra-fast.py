from pathlib import Path
import json
ref=Path(__file__).resolve().parent
scope={'__file__':str(ref/'reference.py')};exec((ref/'reference.py').read_text().split('meta=[]')[0],scope)
args=['-2100000000','14000001','2100000000'];raw=scope['subprocess'].check_output([str(ref/'observer')]+args,preexec_fn=scope['bounded'],timeout=615)
values=range(-2100000000,2100000001,14000001);expected=[]
for op in scope['ops']:
 h=1013904223
 for a in values:
  for b in values:h=(h*1664525+int(op(a,b)))&scope['mask']
 expected.extend([str(len(values)**2)+':'+format(h,'X')]*2)
assert raw.decode().splitlines()==expected
(ref/'normal-fast.expected').write_bytes(raw);(ref/'normal-fast-metadata.json').write_text(json.dumps(dict(arguments=args,source_profile='FAST',suite_profile='normal',grid_size=len(values),pairs_per_pass=len(values)**2,reason='bounded cross-host normal comparison; original NORM and SLOW retained as references'),indent=2)+'\n')
print('PASS source FAST 300 grid and independent exact model')
