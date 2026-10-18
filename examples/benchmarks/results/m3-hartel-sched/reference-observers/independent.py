from pathlib import Path
from functools import lru_cache
import re,json,resource
p=Path(__file__).resolve().parent
resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
text=(p/'source/Main.hs').read_text()
pattern=r'    (c_\w+)=F_JOBDEF \((\d+) :: Int\) \((\d+) :: Int\) \((\d+) :: Int\) (\w+) (\w+);'
nodes={m[0]:(int(m[1]),int(m[2]),int(m[3]),m[4],m[5])for m in re.findall(pattern,text)}
roots={1:'c_solo',3:'c_trio',7:'c_septiem',10:'c_deciem',11:'c_undeciem',12:'c_duodeciem',14:'c_quadrideciem'}
def optimum(root):
 if root not in nodes:return 0,0
 tasks=[];dur=[];prereq=[];affinity=[];forks=[];jobs={}
 def build(name,parent_fork=None):
  id,split,join,left,right=nodes[name];job=len(jobs);jobs[name]=job
  fork=None
  if split:
   fork=len(tasks);tasks.append((job,'fork'));dur.append(split);prereq.append(0 if parent_fork is None else 1<<parent_fork);affinity.append(None);forks.append(job)
  finish=len(tasks);tasks.append((job,'join'));dur.append(join);prereq.append(0);affinity.append(job if fork is not None else None);forks.append(None)
  if fork is None:
   assert left==right=='C_EMPTYJOBDEF'
   prereq[finish]=0 if parent_fork is None else 1<<parent_fork
  else:
   a=build(left,fork);b=build(right,fork);prereq[finish]=(1<<fork)|(1<<a)|(1<<b)
  return finish
 build(root)
 end=(1<<len(tasks))-1
 @lru_cache(None)
 def solve(done,owners,running,order):
  if done==end:return 0
  occupied={task for task,_ in running if task>=0}
  assignments=[]
  def allocate(position,state,used):
   if position==2:assignments.append(tuple(state));return
   pid=(position+order)%2
   if state[pid][0]>=0:allocate(position+1,state,used);return
   eligible=[i for i in range(len(tasks))if not(done>>i&1)and i not in used and prereq[i]&done==prereq[i]and(affinity[i]is None or owners[affinity[i]]==pid+1)]
   if not eligible:allocate(position+1,state,used)
   else:
    for task in eligible:
     new=list(state);new[pid]=(task,dur[task]);allocate(position+1,new,used|{task})
  allocate(0,list(running),occupied)
  best=10**9
  for state in assignments:
   active=[remain for task,remain in state if task>=0];assert active
   dt=min(active);new_done=done;new_owners=list(owners);new_running=[]
   for pid,(task,remain)in enumerate(state):
    if task<0:new_running.append((-1,0))
    elif remain==dt:
     new_done|=1<<task
     if forks[task]is not None:new_owners[forks[task]]=pid+1
     new_running.append((-1,0))
    else:new_running.append((task,remain-dt))
   best=min(best,dt+solve(new_done,tuple(new_owners),tuple(new_running),1-order))
  return best
 answer=solve(0,(0,)*len(jobs),((-1,0),(-1,0)),0)
 return answer,solve.cache_info().currsize
records=[]
expected={row[0]:row[3]for row in json.loads((p/'observations.json').read_text())}
for size,root in roots.items():
 answer,states=optimum(root);assert answer==expected[size],(size,answer,expected[size])
 records.append(dict(size=size,min_cycles=answer,distinct_dag_states=states))
 print('PASS',size,answer,states,'independent DAG/affinity/event states',flush=True)
(p/'independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
