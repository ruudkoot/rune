from pathlib import Path
import ast,json,struct
p=Path(__file__).resolve().parent
solutions=[ast.literal_eval(line)for line in(p/'on-demand/fingerprints.reference').read_text().splitlines()]
with(p/'full.reference').open('w')as f:
 f.write('NUCLEIC2-V1 50 0wx'+format(1107767484,'08X')+'\n')
 for solution in solutions:
  f.write('SOLUTION '+str(len(solution))+'\n')
  for identifier,(kind,matrices),points in solution:
   f.write('VARIABLE '+str(identifier)+' '+str(kind)+' '+str(len(points))+'\n')
   f.write('MATRICES '+' '.join('0wx'+format(v,'08X')for v in matrices)+'\n')
   for point in points:f.write('POINT '+' '.join('0wx'+format(v,'08X')for v in point)+'\n')
print('canonical complete source oracle',len(solutions),'solutions',sum(len(v)for v in solutions),'conformations',sum(3*len(ps)for s in solutions for _,_,ps in s),'coordinates')
