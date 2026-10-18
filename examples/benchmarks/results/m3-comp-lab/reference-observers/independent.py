from pathlib import Path
import json,re,collections
p=Path(__file__).resolve().parent
figures=[json.loads(line.split(' ',1)[1])for line in(p/'figures.reference').read_text().splitlines()]
def tree(text,index=0):
 assert text[index]=='[';index+=1
 match=re.match(r'-?\d+',text[index:]);key=int(match[0]);index+=len(match[0])
 if text[index:index+2]=='()':
  index+=2;assert text[index]==']';return[key],index+1
 left,index=tree(text,index);right,index=tree(text,index)
 assert text[index]==']'and key==max(left)and max(left)<min(right)
 return left+right,index+1
records=[]
for case in json.loads((p/'case-results.json').read_text()):
 text=(p/'cases'/(case['key']+'.reference')).read_text()
 matrix,rest=text.split('\ncomponent image:',1)[1].split('\n\nlab-ranges:',1)
 raw,objects=rest.split('\n\nobject-sets:',1)
 labels=[[int(x)for x in line.split()]for line in matrix.splitlines()if line]
 fig=figures[case['selector']];n=case['size'];pixels=[row*n for row in fig]*n
 h=len(pixels);w=len(pixels[0]);assert len(labels)==h and all(len(row)==w for row in labels)
 owners={};components=[];runIds={}
 expectedRows=[]
 for y,row in enumerate(pixels):
  runs=[];x=0
  while x<w:
   if row[x]!='B':x+=1;continue
   start=x
   while x<w and row[x]=='B':x+=1
   label=y*w+len(runs);runs.append((label,start,x))
   for col in range(start,x):runIds[y,col]=label
  expectedRows.append(runs)
 rawRows=[line for line in raw.splitlines()if line]
 assert len(rawRows)==h
 for line,expected in zip(rawRows,expectedRows,strict=True):
  match=re.fullmatch(r'\{(\d+) \|(.*)\}',line);assert match
  actual=[tuple(map(int,t))for t in re.findall(r' (-?\d+)\[(\d+):(\d+)\]',match[2])]
  assert int(match[1])==len(actual)and actual==expected
 for y in range(h):
  for x in range(w):
   assert(pixels[y][x]=='B')==(labels[y][x]>=0)
   if pixels[y][x]!='B'or(y,x)in owners:continue
   component=len(components);queue=collections.deque([(y,x)]);owners[y,x]=component;cells=[]
   while queue:
    a,b=queue.popleft();cells.append((a,b))
    for c,d in [(a-1,b),(a+1,b),(a,b-1),(a,b+1)]:
     if 0<=c<h and 0<=d<w and pixels[c][d]=='B'and(c,d)not in owners:
      owners[c,d]=component;queue.append((c,d))
   components.append(cells)
 forest={}
 for line in objects.splitlines():
  if not line:continue
  match=re.match(r'\{(-?\d+) (-?\d+)',line);assert match
  label,key=map(int,match.groups());suffix=line[match.end():]
  if suffix=='}':leaves=[key]
  else:
   assert suffix[0]==' ';left,index=tree(suffix,1);assert suffix[index]==' '
   right,index=tree(suffix,index+1);assert suffix[index:]=='}'and key==max(left)
   leaves=left+right
  assert label not in forest and label in leaves and leaves==sorted(set(leaves))
  forest[label]=set(leaves)
 assert len(forest)==len(components)
 used=set()
 for cells in components:
  observed={labels[y][x]for y,x in cells};assert len(observed)==1
  label=next(iter(observed));assert label not in used;used.add(label)
  assert forest[label]=={runIds[y,x]for y,x in cells}
 assert set().union(*forest.values())==set(runIds.values())
 records.append(dict(key=case['key'],pixels=h*w,components=len(components),runs=len(set(runIds.values())),method='four-neighbor BFS, independent row runs, forest membership and ordered-split invariants'))
print('PASS',len(records),'complete original states;',sum(r['pixels']for r in records),'pixels; independent BFS/run/forest checks')
(p/'independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
