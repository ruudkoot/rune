from pathlib import Path
import shutil,subprocess,resource,json
p=Path(__file__).resolve().parent;d=p/'observer-source';shutil.copytree(p/'source',d,ignore=shutil.ignore_patterns('original','*.o','*.hi'),dirs_exist_ok=True)
s=(d/'Main.hs').read_text().replace('module Main (main)','module Kernel')
(d/'Kernel.hs').write_text(s)
source='''module Main where
import Kernel
import System.Environment
figures=[c_mini_figure,c_small_figure,c_figure,c_figure_l,c_figure_l_l]
main=do
 args<-getArgs
 case args of
  ["figures"]->mapM_ (\\(i,fig)->putStrLn(show i++" "++show(map(map(\\p->if f_is_black p then 'B' else ' '))fig))) (zip [0..] figures)
  [s,n,t,mode]->do
   let fig=figures!!read s
       size=read n
       image=f_n_fig size fig
       width=length(head image)
       pixels=map f_pix2range image
       f=if mode=="zift"then f_zift_l else f_no_zift
       (labels,raw,objects)=f_comp_lab_diff' f width pixels(read t)
   putStr(f_show_all_lab(labels,raw,objects)width)
  _->error"expected figures or selector,size,threshold,zift|plain"
'''
(d/'Observer.hs').write_text(source)
with(p/'observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o','observer','Observer.hs'],cwd=d,stdout=log,stderr=subprocess.STDOUT,check=True)
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
r=subprocess.run([str(d/'observer'),'figures'],capture_output=True,check=True,timeout=30,preexec_fn=cap)
(p/'figures.reference').write_bytes(r.stdout);figures=[json.loads(line.split(' ',1)[1])for line in r.stdout.decode().splitlines()]
(p/'figures.sml').write_text('structure BenchCompLabData=struct\n val figures=Vector.fromList['+','.join('['+','.join(json.dumps(row)for row in fig)+']'for fig in figures)+']\nend\n')
records=[];out=p/'cases';out.mkdir(exist_ok=True)
specs=[(i,1,t,mode)for i in range(5)for t in [0,1,10000]for mode in ['zift','plain']]
specs +=[(3,n,t,mode)for n in [2,3,5,9]for t in [0,n*256]for mode in ['zift','plain']]
for selector,n,threshold,mode in specs:
 key=str(selector)+'-'+str(n)+'-'+str(threshold)+'-'+mode
 r=subprocess.run([str(d/'observer'),str(selector),str(n),str(threshold),mode],capture_output=True,check=True,timeout=120,preexec_fn=cap)
 (out/(key+'.reference')).write_bytes(r.stdout);(out/(key+'.stderr')).write_bytes(r.stderr)
 records.append(dict(key=key,selector=selector,size=n,threshold=threshold,mode=mode,bytes=len(r.stdout)))
 print('PASS original',key,len(r.stdout),flush=True)
(p/'case-results.json').write_text(json.dumps(records,indent=2)+'\n')
