from pathlib import Path
from collections import Counter
import ast,heapq,json
ref=Path(__file__).resolve().parent
times=[10,5,2,1];histogram=Counter();best=10**9;mins=[];visits=0
def moves(state,bank):
    present=[i for i in range(4) if (state>>i)&1==bank]
    for i in present:yield state^(1<<i),times[i]
    for index,i in enumerate(present):
        for j in present[index+1:]:yield state^(1<<i)^(1<<j),max(times[i],times[j])
def visit(state,bank,time,history,seen):
    global best,mins,visits
    visits+=1
    path=[(time,state)]+history
    if state==0:
        histogram[time]+=1
        if time<best:best=time;mins=[path]
        elif time==best:mins.append(path)
        return
    for nextstate,cost in moves(state,bank):
        if not (seen>>nextstate)&1:
            visit(nextstate,1-bank,time+cost,path,seen|(1<<state))
visit(15,1,0,[],0)
# Independent shortest-path search includes the torch in the state, without
# the source's history-based pruning; it certifies the global optimum.
queue=[(0,0,0)];distance={(0,0):0}
while queue:
    cost,state,bank=heapq.heappop(queue)
    if cost!=distance[state,bank]:continue
    if state==15:assert cost==best;break
    for nxt,weight in moves(state,bank):
        key=nxt,1-bank;candidate=cost+weight
        if candidate<distance.get(key,10**9):
            distance[key]=candidate;heapq.heappush(queue,(candidate,*key))
names=['Bono','The Edge','Larry','Adam']
def state_text(state):
    border='-'*40+'\n'
    return border+''.join(('         |                    | '+name+'\n') if (state>>i)&1
        else name.rjust(8)+' |                    |\n' for i,name in enumerate(names))+border
def render(paths):
    return ''.join(f'Solution {index}\n'+''.join(f'Time: {path[0][0]-time}\n'+state_text(state)
        for time,state in path) for index,path in enumerate(paths,1))
expected=render(mins)
actual=(ref/'original.output').read_text();assert actual==expected
assert ast.literal_eval((ref/'original.histogram').read_text())==sorted(histogram.items())
encoded=[[(t,[(s>>i)&1 for i in range(4)]) for t,s in path] for path in mins]
assert ast.literal_eval((ref/'original.minimum').read_text())==encoded
(ref/'independent.output').write_text(expected)
(ref/'independent.json').write_text(json.dumps({'recursive_calls':visits,'solutions':sum(histogram.values()),'minimum':best,'ordered_minima':encoded,'histogram':sorted(histogram.items()),'rendered_bytes':len(expected.encode()),'dijkstra_minimum':cost},indent=2)+'\n')
print(sum(histogram.values()),'solutions;',len(mins),'ordered minima;',best,'optimal;',len(expected.encode()),'bytes; all original evidence agrees')
