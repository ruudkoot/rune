from pathlib import Path
import json
p=Path(__file__).parent
profiles=json.loads((p/'profiles.json').read_text())
def summary(values):
 total=0;h=0;count=0
 for value in values:count+=1;total+=value;h=(h*131+value)&0xffffffff
 return f'{count}:{total}:{h:X}\n'
def read(path):return [[int(v)for v in line.split()]for line in path.read_text().splitlines()]
for name,rows in profiles.items():
 for profile,n in rows:
  base=p/(name+'-'+profile)
  if name in ['quicksort','mergesort']:
   expected=Path(str(base)+'.stdout').read_text().strip().split(':')
   expected=':'.join(expected[:-1]+[expected[-1].upper()])+'\n'
   if profile!='large':assert summary(sorted(map(int,Path(str(base)+'.input').read_text().split())))==expected
  else:
   result=read(Path(str(base)+'.matrix'))
   assert len(result)==n and all(len(row)==n for row in result)
   if profile!='large':
    if name=='matrix_multiplication':
     x=read(Path(str(base)+'.matrix.x'));y=read(Path(str(base)+'.matrix.y'))
     # Column dot products, independent from the translated loop kernel.
     assert [[sum(a*b for a,b in zip(row,col))for col in zip(*y)]for row in x]==result
    else:
     original=read(Path(str(base)+'.matrix.input'))
     # Repeated Bellman-Ford relaxation on original directed edges.
     edges=[(i,j,v)for i,row in enumerate(original)for j,v in enumerate(row)if v>=0]
     for start in range(n):
      distance=[None]*n;distance[start]=0
      for _ in range(n-1):
       updated=False
       for a,b,cost in edges:
        if distance[a] is not None and(distance[b]is None or distance[a]+cost<distance[b]):distance[b]=distance[a]+cost;updated=True
       if not updated:break
      assert [(-1 if v is None else v)for v in distance]==result[start]
   expected=summary(v for row in result for v in row)
  Path(str(base)+'.expected').write_text(expected)
  print('PASS independent/reference summary',name,profile,expected.strip(),flush=True)
