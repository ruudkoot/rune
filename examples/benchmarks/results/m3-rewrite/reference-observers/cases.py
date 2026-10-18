from pathlib import Path
import random,json,subprocess
p=Path(__file__).resolve().parent
rng=random.Random(19790601)
def generate(depth):
 if depth==0 or rng.randrange(5)<2:return rng.choice(['a','b','c','E'])
 if rng.randrange(3)==0:return ('I',generate(depth-1))
 return ('*',generate(depth-1),generate(depth-1))
def text(t):
 if isinstance(t,str):return t
 return 'I('+text(t[1])+')'if t[0]=='I'else '('+text(t[1])+'*'+text(t[2])+')'
def word(t):
 if isinstance(t,str):return []if t=='E'else[(t,1)]
 if t[0]=='I':return[(v,-s)for v,s in reversed(word(t[1]))]
 return word(t[1])+word(t[2])
def canonical(t):
 stack=[]
 for letter in word(t):
  if stack and stack[-1]==(letter[0],-letter[1]):stack.pop()
  else:stack.append(letter)
 values=[v if s==1 else 'I('+v+')'for v,s in stack]
 def right(xs):return 'E()'if not xs else xs[0]if len(xs)==1 else '*('+xs[0]+','+right(xs[1:])+')'
 return right(values)
trees=[generate(5)for _ in range(128)]
rows=[(text(t),canonical(t))for t in trees]
(p/'cases.json').write_text(json.dumps(rows,indent=2)+'\n')
d=p/'observer-source';(d/'terms.in').write_text('\n'.join(x for x,_ in rows)+'\n')
src=(d/'Observer.hs').read_text();i=src.index(' mapM_ (\\s->')
src=src[:i]+' terms<-lines <$> readFile "terms.in"\n'+src[i:]
src=src[:src.index('\nterms=')]
(d/'Cases.hs').write_text(src)
with(d/'cases-build.log').open('w')as f:subprocess.run(['ghc','-O2','-fforce-recomp','Cases.hs','Rewrite.lhs','-o','cases-observer'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'cases-observer')],cwd=d,timeout=30);(p/'cases.reference').write_bytes(out)
lines=out.decode().splitlines();assert len(lines)==138
assert lines[10:]==[a+' -> '+b for a,b in rows]
print('PASS 128 generated terms: original completion and independent free-group cancellation agree')
