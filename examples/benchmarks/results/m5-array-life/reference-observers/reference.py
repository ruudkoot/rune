from pathlib import Path
import subprocess,resource,json
p=Path(__file__).parent;source=Path('tests/out/benchmarks/upstreams/sandmark/benchmarks/multicore-numerical/game_of_life.ml').read_text();source=source[:source.rindex('let ()=')]+'''
let save filename g =
 let out=open_out filename in
 Array.iter(fun row->Array.iter(fun value->output_char out(if value=0 then '.' else 'o'))row;output_char out '\\n')g;close_out out
let ()=save(Sys.argv.(3)^".input")!rg;repeat n_times;save Sys.argv.(3)!rg;save(Sys.argv.(3)^".spare")!rg'
''';(p/'life_observer.ml').write_text(source)
subprocess.run(['ocamlopt','-O2','-o',str(p/'observer'),str(p/'life_observer.ml')],check=True)
meta=[]
for profile,generations,n,timeout,memory in [('smoke',2,8,30,1024**3),('normal',64,128,600,4*1024**3),('large',256,1024,3600,8*1024**3)]:
 def limits():resource.setrlimit(resource.RLIMIT_AS,(memory,memory))
 file=p/(profile+'.board');subprocess.run([str(p/'observer'),str(generations),str(n),str(file)],capture_output=True,check=True,timeout=timeout,preexec_fn=limits)
 original=[[int(c=='o')for c in row]for row in Path(str(file)+'.input').read_text().splitlines()];expected=[[int(c=='o')for c in row]for row in file.read_text().splitlines()];assert len(expected)==n and all(len(row)==n for row in expected)
 if profile!='large':
  board=original
  for _ in range(generations):
   previous=board
   next_board=[]
   for i in range(n):
    row=[]
    for j in range(n):
     count=sum(board[x][y]for x in range(max(0,i-1),min(n,i+2))for y in range(max(0,j-1),min(n,j+2))if(x,y)!=(i,j));row.append(int(count==3 or(board[i][j]and count==2)))
    next_board.append(row)
   board=next_board
  assert board==expected
  spare=[[int(c=='o')for c in row]for row in Path(str(file)+'.spare').read_text().splitlines()];assert previous==spare
 meta.append({'profile':profile,'size':n,'generations':generations,'live':sum(map(sum,expected)),'timeout':timeout,'memory_bytes':memory})
 print('PASS original Life board and available independent stencil',profile,generations,n,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
