from pathlib import Path
import re,json
ref=Path(__file__).resolve().parent
source=(ref.parents[2]/'examples/benchmarks/shared/ocaml-random.sml')
# Locate the worktree source when replaying from the original private directory.
source=Path.cwd()/'examples/benchmarks/shared/ocaml-random.sml'
text=source.read_text();part=text.split('val seed42Words = Vector.fromList [',1)[1].split('] :',1)[0]
seed=list(map(int,re.findall(r'0w(\d+)',part)));assert len(seed)==55
class Generator:
 def __init__(self):self.words=seed[:];self.index=0;self.draws=0
 def bits(self):
  self.index=(self.index+1)%55;c=self.words[self.index];result=(self.words[(self.index+24)%55]+(c^((c>>25)&31)))&0x3fffffff
  self.words[self.index]=result;self.draws+=1;return result
 def integer(self,bound):
  while True:
   r=self.bits();v=r%bound
   if r-v<=1073741823-bound+1:return v
 def real(self):
  r1=self.bits();r2=self.bits();return(r1/1073741824.+r2)/1073741824.
def trial(n,lam,budget):
 generator=Generator();evaluations=0
 def evaluate(bits):
  nonlocal evaluations
  evaluations+=1;return bits,bits.bit_count()
 def initial():
  bits=0
  for _ in range(n):bits=bits*2+(generator.bits()%2==0)
  return evaluate(bits)
 population=[initial()for _ in range(lam)];time=0;p=.4/n
 while True:
  nextpop=[]
  for _ in range(lam):
   a=population[generator.integer(lam)];b=population[generator.integer(lam)];bits=(a if a[1]>b[1]else b)[0]
   for i in range(n):
    if generator.real()<p:bits^=1<<(n-1-i)
   nextpop.append(evaluate(bits))
  if time*lam>budget:break
  population=nextpop;time+=1
 return nextpop,evaluations,time+1,generator.draws
records=[]
for label,n,lam,budget in [('tiny',3,2,0),('smoke',16,16,128),('normal',128,128,10000)]:
 population,evaluations,generations,draws=trial(n,lam,budget)
 lines=(ref/(label+'.expected')).read_text().splitlines();head=lines[0].split();assert list(map(int,head))==[lam,n,max(x[1]for x in population)]
 for line,(bits,fitness)in zip(lines[1:],population):
  score,chromosome=line.split();assert int(score)==fitness and chromosome==format(bits,f'0{n}b')
 assert len(lines)==lam+1 and evaluations==lam*(budget//lam+3)
 row={'profile':label,'evaluations':evaluations,'new_generations':generations,'random_bit_draws':draws,'comparison':'every complete chromosome/fitness, packed-bit/int-popcount reference'};records.append(row);print('PASS independent evolutionary population',row,flush=True)
(ref/'independent.json').write_text(json.dumps(records,indent=2)+'\n')
