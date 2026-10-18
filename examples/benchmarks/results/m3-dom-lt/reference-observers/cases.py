from pathlib import Path
import subprocess,shutil,resource,ast,json,random
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('*.o','*.hi','original'),dirs_exist_ok=True)
(d/'Observer.hs').write_text('''module Main where
import Dom
import System.Environment
main = do
 [path]<-getArgs
 contents<-readFile path
 mapM_ (print . idom . (\\(root,adj)->(root,fromAdj adj)) . read) (lines contents)
''')
with(d/'observer-build.log').open('w')as f:subprocess.run(['ghc','-O2','-rtsopts','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
corpus=[ast.literal_eval(line)for line in(p/'source/ghc-examples.in').read_text().splitlines()]
cases=list(corpus)
cases += [(0,[(0,[])]),(0,[(0,[0])]),(0,[(0,[1,2]),(1,[3]),(2,[3]),(3,[])]),
          (1,[(1,[2]),(2,[3]),(3,[1,4]),(4,[]),(9,[9])]),
          (-1,[(-1,[-64,64]),(-64,[129]),(64,[129]),(129,[])])]
rng=random.Random(19790601)
for i in range(64):
 n=2+i%8;keys=rng.sample(range(-130,150),n)
 adj=[(k,[v for v in keys if rng.random()<(.1+(i%4)*.1)])for k in keys]
 cases.append((keys[0],adj))
out=p/'cases';out.mkdir(exist_ok=True)
text='\n'.join(repr(graph).replace(' ','')for graph in cases)+'\n';(out/'graphs.in').write_text(text)
def cap():resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
r=subprocess.run([str(d/'observer'),str(out/'graphs.in'),'+RTS','-M128m','-RTS'],cwd=d,stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap,check=True)
(out/'source-parents.txt').write_bytes(r.stdout);(out/'source.stderr').write_bytes(r.stderr)
observed=[ast.literal_eval(line)for line in r.stdout.decode().splitlines()];assert len(observed)==len(cases)
def model(root,adj):
 graph={k:set(vs)for k,vs in adj};reachable={root};pending=[root]
 while pending:
  v=pending.pop()
  for w in graph.get(v,set())-reachable:reachable.add(w);pending.append(w)
 preds={k:{p for p in reachable if k in graph.get(p,set())}for k in reachable}
 dom={k:({root}if k==root else set(reachable))for k in reachable}
 while True:
  new={k:({root}if k==root else {k}|set.intersection(*(dom[p]for p in preds[k])))for k in reachable}
  if new==dom:break
  dom=new
 parents={root:root}
 for k in reachable-{root}:
  strict=dom[k]-{k};choices=[d for d in strict if strict-{d}<=dom[d]];assert len(choices)==1
  parents[k]=choices[0]
 return sorted(parents.items())
records=[];models=[]
for i,((root,adj),pairs)in enumerate(zip(cases,observed)):
 want=model(root,adj);models.append(want)
 records.append(dict(index=i,corpus=i<len(corpus),source_matches=sorted(pairs)==want,source=pairs if sorted(pairs)!=want else None,model=want if sorted(pairs)!=want else None))
(out/'model-parents.txt').write_text('\n'.join(repr(value).replace(' ','')for value in models)+'\n')
(p/'model-comparison.json').write_text(json.dumps(records,indent=2)+'\n')
print('graphs',len(cases),'corpus',len(corpus),'source/model matches',sum(r['source_matches']for r in records),'mismatches',[r['index']for r in records if not r['source_matches']],flush=True)
