from pathlib import Path
import subprocess,resource,json
r=Path(__file__).resolve().parent;w=r/'observer-src'
(w/'PrefixObserver.hs').write_text(r'''module Main where
import Kernel
import qualified Data.Map as M
import System.Environment
boards(Soln b)=[b]
boards(Choose children)=concatMap boards children
boards(Fail _ _) =[]
main=do
 [arg]<-getArgs
 let n=read arg
     first=head(boards solutions)
     ids=[ident|P ident _ _<-take(13-n)initialPieces]
     cells=[(sq,ident)|(sq,ident)<-M.toAscList first,ident`elem`ids]
     board=foldl(\b(sq,ident)->M.insert sq ident b)initialBoard cells
 printDoc(display(search(1,2)Female board(drop(13-n)initialPieces)))
''')
with(r/'prefix-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',str(r/'prefix-observer'),'PrefixObserver.hs'],cwd=w,stdout=log,stderr=subprocess.STDOUT,check=True)
def bounded():
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(300,300))
source=json.loads((r/'data.json').read_text());pieces=source['pieces'];witness={(tuple(sq)):ident for sq,ident in source['boards'][0]};initial={(tuple(sq)):ident for sq,ident in source['initial']}
for ident,male,female in pieces:
 for group in male+female:assert all(dr*8+dc>0 for dr,dc in group)
def independent(n):
 fixed={p[0]for p in pieces[:13-n]};board=dict(initial);board.update({sq:ident for sq,ident in witness.items()if ident in fixed});remaining=tuple(range(13-n,13));count=0;visits=0;answers=[]
 def index(row,col):return(row-1)*8+col-1
 mask=sum(1<<index(*sq)for sq in board)
 def search(mask,ps,bd):
  nonlocal visits
  visits+=1
  if not ps:
   assert mask==(1<<64)-1 and len(bd)==64;answers.append(bd);return
  pos=next(i for i in range(64)if not(mask>>i&1));row=pos//8+1;col=pos%8+1;female=(row+col)%2==1
  for at,piece in enumerate(ps):
   ident,male,fs=pieces[piece];nextps=tuple(reversed(ps[:at]))+ps[at+1:]
   for offsets in(fs if female else male):
    squares=[(row+dr,col+dc)for dr,dc in offsets]+[(row,col)]
    if any(rr>8 or cc<1 or cc>8 for rr,cc in squares):continue
    bits=sum(1<<index(*sq)for sq in squares)
    if bits&mask:continue
    nextboard=dict(bd);nextboard.update((sq,ident)for sq in squares);search(mask|bits,nextps,nextboard)
 search(mask,remaining,board)
 text=''.join('Success!\n'+''.join('  '+''.join(bd[(row,col)]for col in range(1,9))+'\n'for row in range(8,0,-1))+'  \n'for bd in answers)
 if not answers:text='\n'
 return text,visits,len(answers)
meta=[]
for n in [0,2,8,13]:
 raw=subprocess.check_output([str(r/'prefix-observer'),str(n)],timeout=315,preexec_fn=bounded).decode();expected,visits,count=independent(n);assert raw==expected,(n,raw,expected)
 (r/(str(n)+'.output')).write_text(raw);meta.append(dict(remaining=n,source_replaced='fixed valid prefix from first original solution, same initial a/sex/search API',solutions=count,independent_visits=visits,bytes=len(raw),comparison='complete original output and independent bitmask/reversed-prefix-choice model'))
 print('PASS original/independent complete prefix',n,count,'solutions;',visits,'states',flush=True)
 if n==13:assert raw==(r/'last-piece.stdout').read_text()
(r/'prefix-metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
