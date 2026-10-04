from pathlib import Path
import ast
vertices=list(range(1,8))
edges=[(2,1),(3,2),(3,4),(3,7),(4,3),(5,1),(5,6),(5,7),(6,5),(7,6)]
def reachable(v):
    visited={v};work=[v]
    while work:
        current=work.pop()
        for a,b in edges:
            if a==current and b not in visited:visited.add(b);work.append(b)
    return visited
reach={v:reachable(v) for v in vertices}
components={frozenset(w for w in vertices if w in reach[v] and v in reach[w]) for v in vertices}
original=ast.literal_eval((Path(__file__).parent/'original.txt').read_text())
assert components=={frozenset(group) for group in original}
assert len(sum(original,[]))==len(vertices)
print('Independent mutual reachability agrees on the complete SCC partition')
