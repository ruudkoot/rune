from pathlib import Path
import math,json
p=Path(__file__).resolve().parent
tokens=(p/'scene.input').read_text().split();nodeCount=int(tokens[0]);ops=tokens[1];declared=int(tokens[2]);data=tokens[3:]
assert len(ops)==nodeCount and set(ops)=={'h','u'} and ops.count('h')==declared==300
circles=[]
for i in range(declared):
 kind,r,x,y,surface=data[5*i:5*i+5];assert kind=='ci'and int(surface)==i
 circles.append(tuple(map(float,[r,x,y])))
assert len(data)==declared*5
# Independent union evaluation may reorder primitives; it constructs no CSG or
# adaptive/pruned subdivision tree.
circles.sort(reverse=True)
original={int(line.split()[0]):int(line.split()[2])for line in(p/'original-areas.reference').read_text().splitlines()}
records=[]
for depth in range(10):
 side=1<<depth;inside=0
 for yi in range(side):
  y=(yi+0.5)/side
  for xi in range(side):
   x=(xi+0.5)/side
   for radius,cx,cy in circles:
    if(x-cx)*(x-cx)+(y-cy)*(y-cy)<=radius*radius:
     inside+=1;break
 record=dict(depth=depth,samples=side*side,independent_inside=inside,original_inside=original[depth],difference=original[depth]-inside)
 records.append(record);print(record,flush=True)
(p/'independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
