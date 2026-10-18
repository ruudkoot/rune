from pathlib import Path
import json,ast,struct,math
p=Path(__file__).resolve().parent
policy=json.loads((p/'validation-policy.json').read_text());absolute=policy['absolute_coordinate_tolerance'];relative=policy['relative_coordinate_tolerance']
expected=[ast.literal_eval(l)for l in(p/'on-demand/solutions.reference').read_text().splitlines()[2:]]
def number(bits):return struct.unpack('>f',struct.pack('>I',bits))[0]
records=[];variants={}
for name in ['on-demand-need','on-demand-strict','shared-need','shared-strict']:
 actual=[json.loads(l)for l in(p/('solutions-'+name+'.actual')).read_text().splitlines()]
 assert len(actual)==len(expected)==50
 samples=0;changed=0;largest=0.0;largest_ratio=0.0;worst=None
 for i,(a,b)in enumerate(zip(actual,expected)):
  assert len(a)==len(b)
  for j,((ai,aps),(bi,bps))in enumerate(zip(a,b)):
   assert ai==bi and len(aps)==len(bps)
   for k,(ap,bp)in enumerate(zip(aps,bps)):
    assert len(ap)==len(bp)==3
    for axis,(x,y)in enumerate(zip(ap,bp)):
     samples+=1;changed+=x!=y
     vx,vy=number(x),number(y);assert math.isfinite(vx)and math.isfinite(vy)
     delta=abs(vx-vy);bound=absolute+relative*abs(vy)
     if delta/bound>largest_ratio:largest_ratio=delta/bound;worst=[i,ai,k,axis,vx,vy,delta,bound]
     largest=max(largest,delta)
     assert delta<=bound,(name,i,j,k,axis,vx,vy,bound)
 records.append(dict(variant=name,solutions=len(actual),coordinates=samples,changed_bits=changed,largest_absolute_difference=largest,largest_budget_fraction=largest_ratio,worst=worst))
 variants[name]=actual;print(records[-1],flush=True)
assert all(v==variants['on-demand-need']for v in variants.values())
records.append(dict(all_four_variants_bit_equal=True))
(p/'coordinate-comparisons.json').write_text(json.dumps(records,indent=2)+'\n')
print('PASS: all four SML variants agree bit-for-bit; complete source solutions satisfy the predetermined numerical budget')
