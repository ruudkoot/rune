from pathlib import Path
import subprocess,ast,json,shutil
r=Path(__file__).resolve().parent;w=r/'observer-src';(w/'Kernel.hs').write_text((r/'Main.hs').read_text().replace('module Main where','module Kernel where'))
(w/'Observer.hs').write_text('''module Main where
import Kernel
import qualified Data.Map as M
import System.Environment
boards(Soln b)=[b]
boards(Choose children)=concatMap boards children
boards(Fail _ _)=[]
main=do
 [mode]<-getArgs
 case mode of
  "data"->do
   print[(ident,male,female)|P ident male female<-initialPieces]
   print(M.toAscList initialBoard)
  "boards"->mapM_(print.M.toAscList)(boards solutions)
''')
with(r/'data-observer-build.log').open('w')as log:subprocess.run(['ghc','-O2','-fforce-recomp','-o',str(r/'data-observer'),'Observer.hs'],cwd=w,stdout=log,stderr=subprocess.STDOUT,check=True)
raw=subprocess.check_output([str(r/'data-observer'),'data'],text=True,timeout=180);(r/'data-ghc.txt').write_text(raw);pieces,initial=[ast.literal_eval(line)for line in raw.splitlines()]
raw=subprocess.check_output([str(r/'data-observer'),'boards'],text=True,timeout=180);(r/'boards-ghc.txt').write_text(raw);boards=[ast.literal_eval(line)for line in raw.splitlines()];assert len(boards)==3
(r/'data.json').write_text(json.dumps(dict(pieces=pieces,initial=initial,boards=boards),indent=2)+'\n')
def offsets(groups):return'['+','.join('['+','.join('('+str(a)+','+('~'+str(-b)if b<0 else str(b))+')'for a,b in group)+']'for group in groups)+']'
rows=['  val pieces = [']
for index,(ident,male,female)in enumerate(pieces):rows.append('    (#"'+ident+'",'+offsets(male)+','+offsets(female)+')'+(','if index+1<len(pieces)else''))
rows+=['  ]','  val firstSolution = [']
for index,((row,col),ident)in enumerate(boards[0]):rows.append('    (('+str(row)+','+str(col)+'),#"'+ident+'")'+(','if index+1<len(boards[0])else''))
rows+=['  ]']
(r/'data.sml').write_text('(* Exact piece order/orientations and first original solution witness. *)\nstructure BenchLastPieceData =\nstruct\n'+'\n'.join(rows)+'\nend\n')
print('PASS source export:',len(pieces),'pieces;',len(initial),'initial squares;',len(boards),'complete boards')
