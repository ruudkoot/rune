from pathlib import Path
import sys,math,json,re
sys.set_int_max_str_digits(0)
p=Path(__file__).resolve().parent
records=[]
for profile,inp in [('smoke',p/'smoke.stdin'),('source-fast',p/'source/symalg.faststdin'),('normal',p/'source/symalg.stdin'),('source-slow',p/'source/symalg.slowstdin')]:
 lines=inp.read_text().splitlines();precision=int(lines[0].split('=')[1])
 values=(p/(profile+'.numbers.reference')).read_text().splitlines()
 assert values[:2]==[str(precision)]*2 and len(values)==len(lines)
 floor={n:math.isqrt(n*10**(2*precision))for n in range(2,11)}
 gaps=[]
 for script,value in zip(lines[1:-1],values[2:],strict=True):
  operand=int(re.fullmatch(r'sqrt\((\d+)\)',script)[1])
  whole,frac=value.split('.');assert len(frac)==precision
  v=int(whole+frac);gap=v-floor[operand]
  assert abs(gap)<=1,(profile,operand,gap)
  # Explicit arithmetic bound, independent of parsing/CSG/hash algorithms:
  # source approximation differs from the exact floor by at most one unit.
  gaps.append(gap)
 records.append(dict(profile=profile,precision=precision,complete_values=len(gaps),min_gap=min(gaps),max_gap=max(gaps),method='integer square root of n*10^(2*precision);abs(source-floor)<=1'))
 print('PASS',profile,len(gaps),'complete values;',precision,'digits;max floor gap',max(abs(g)for g in gaps),flush=True)
(p/'independent-results.json').write_text(json.dumps(records,indent=2)+'\n')
