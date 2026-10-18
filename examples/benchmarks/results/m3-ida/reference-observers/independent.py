from pathlib import Path
import json,re,collections
p=Path(__file__).resolve().parent
cases=json.loads((p/'cases.json').read_text());rows=(p/'cases.reference').read_text().splitlines()
def conf(seed,w,h,n):
 tiles=[((x,y),(x,y))for x in range(1,w+1)for y in range(1,h+1)][1:];hole=(1,1)
 def split(hole,tiles):
  return([x for x in tiles if abs(x[0][0]-hole[0])+abs(x[0][1]-hole[1])==1],
         [x for x in tiles if abs(x[0][0]-hole[0])+abs(x[0][1]-hole[1])!=1])
 numbers=[];seed=abs(seed)
 for _ in range(n):seed=(4663*seed)%46199+1;numbers.insert(0,seed)
 movable,fixed=split(hole,tiles)
 for number in numbers:
  shift=number%len(movable);choices=movable[shift:]+movable[:shift]
  (current,home),rejected=choices[0],choices[1:]
  movable,fixed=split(current,[(hole,home)]+fixed+rejected);hole=current
 return hole,movable+fixed
def shortest(hole,tiles,w,h):
 positions=[(x,y)for x in range(1,w+1)for y in range(1,h+1)];indices={v:i for i,v in enumerate(positions)}
 state=[0]*len(positions)
 for current,home in tiles:state[indices[current]]=indices[home]
 initial=tuple(state);goal=tuple(range(len(positions)));queue=collections.deque([(initial,indices[hole],0)]);seen={initial}
 while queue:
  state,zero,distance=queue.popleft()
  if state==goal:return distance
  x,y=positions[zero]
  for nxt in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
   if nxt not in indices:continue
   j=indices[nxt];changed=list(state);changed[zero],changed[j]=changed[j],0;changed=tuple(changed)
   if changed not in seen:seen.add(changed);queue.append((changed,j,distance+1))
 raise AssertionError('unreachable')
checked=0
for case,row in zip(cases,rows):
 seed,w,h,n=case;hole,tiles=conf(*case);description,solution=row.split(' | ')
 prefix='('+','.join(map(str,case))+') '
 observed=description[len(prefix):];expect='(%d,%d)'%hole+''.join('((%d,%d)-(%d,%d))'%(*cur,*home)for cur,home in tiles)
 assert observed==expect
 bound,partitions,depth,path=solution.split(' ',3);path=[tuple(map(int,x))for x in re.findall(r'\((\d+),(\d+)\)',path)][::-1]
 assert path[0]==hole and len(path)-1==int(bound)and depth=='0'
 for nxt in path[1:]:
  assert abs(nxt[0]-hole[0])+abs(nxt[1]-hole[1])==1
  i=next(i for i,(cur,home)in enumerate(tiles)if cur==nxt);_,home=tiles[i];tiles[i]=(hole,home);hole=nxt
 assert all(cur==home for cur,home in tiles)
 if w==2 or n<=5:
  original=conf(*case);assert shortest(*original,w,h)==int(bound);checked+=1
print('PASS',len(cases),'independent ordered shuffles and legal complete solution paths;',checked,'independent breadth-first optimal lengths')
