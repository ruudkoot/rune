from pathlib import Path
import subprocess,resource,json
p=Path('tests/out/benchmarks/sandmark-arrays-originals');up=Path('tests/out/benchmarks/upstreams/sandmark/benchmarks/multicore-numerical')
sortcheck='''
let report a =
 let sum=ref 0L and hash=ref 0l in
 Array.iter (fun x -> sum:=Int64.add !sum(Int64.of_int x);hash:=Int32.add(Int32.mul !hash 131l)(Int32.of_int x)) a;
 Printf.printf "%d:%Ld:%lx\\n" (Array.length a) !sum !hash
'''
for name in ['quicksort','mergesort','matrix_multiplication','floyd_warshall']:
 src=(up/(name+'.ml')).read_text();(p/(name+'-original.ml')).write_text(src)
 if name=='quicksort':
  src=src[:src.rindex('let () =')]+sortcheck+'''
let () = let a=Array.init n (fun _ -> Random.int n) in
 if Array.length Sys.argv>2 then (let out=open_out Sys.argv.(2) in Array.iter(fun v -> Printf.fprintf out "%d\\n" v)a;close_out out);
 quicksort a 0 (n-1);report a
'''
 elif name=='mergesort':
  src=src[:src.rindex('let () =')]+sortcheck+'''
let () =
 if Array.length Sys.argv>2 then (let out=open_out Sys.argv.(2) in Array.iter(fun v -> Printf.fprintf out "%d\\n" v)a;close_out out);
 sort a;report a
'''
 elif name=='matrix_multiplication':
  src=src.replace('(* print_matrix res; *)','''let output filename a =
    let out=open_out filename in
    Array.iter(fun row->Array.iter(fun v->Printf.fprintf out "%d " v)row;output_char out '\\n')a;
    close_out out in
  output Sys.argv.(2) res;
  output (Sys.argv.(2)^".x") m1;
  output (Sys.argv.(2)^".y") m2;''')
 else:
  src=src.replace('  f_w adj','''  let output filename a =
    let out=open_out filename in
    Array.iter(fun row->Array.iter(fun v->Printf.fprintf out "%d " (match v with Infinity -> -1 | Value x -> x))row;output_char out '\\n')a;close_out out in
  output (Sys.argv.(2)^".input") adj;
  f_w adj;
  output Sys.argv.(2) adj''')
 (p/(name+'_observer.ml')).write_text(src)
 subprocess.run(['ocamlopt','-o',str(p/name),str(p/(name+'_observer.ml'))],check=True)
profiles={'quicksort':[('smoke',128),('normal',100000),('large',4000000)],'mergesort':[('smoke',128),('normal',262144),('large',67108864)],'matrix_multiplication':[('smoke',8),('normal',128),('large',1024)],'floyd_warshall':[('smoke',8),('normal',128),('large',512)]}
def limits():resource.setrlimit(resource.RLIMIT_AS,(8*1024**3,8*1024**3))
with (p/'reference.log').open('w')as log:
 for name,rows in profiles.items():
  for profile,n in rows:
   base=p/(name+'-'+profile)
   args=[str(p/name),str(n)]
   if name in ['quicksort','mergesort']:
    if profile!='large':args.append(str(base)+'.input')
   else:args.append(str(base)+'.matrix')
   result=subprocess.run(args,capture_output=True,timeout=3600,preexec_fn=limits)
   (Path(str(base)+'.stderr')).write_bytes(result.stderr)
   assert result.returncode==0,(name,profile,result.returncode)
   Path(str(base)+'.stdout').write_bytes(result.stdout)
   print('PASS',name,profile,n,file=log,flush=True)
(p/'profiles.json').write_text(json.dumps(profiles,indent=2))
