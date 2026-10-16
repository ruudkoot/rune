from pathlib import Path
import difflib,hashlib,json,os,resource,subprocess

root=Path.cwd();p=root/'tests/out/benchmarks/fannkuchredux-originals'
up=root/'tests/out/benchmarks/upstreams/sandmark/benchmarks/benchmarksgame'
source=(up/'fannkuchredux.ml').read_text()
old='''      aug_c := c.(!i) + 1;
      c.(!i) <- !aug_c'''
new='''      if !i < plen then begin
        aug_c := c.(!i) + 1;
        c.(!i) <- !aug_c
      end else aug_c := 0'''
assert source.count(old)==1
repaired=source.replace(old,new)
entry='\nlet _ =\n  main n;'
assert source.count(entry)==repaired.count(entry)==1
(p/'kernel_original.ml').write_text(source.split(entry)[0]+'\n')
(p/'kernel_repaired.ml').write_text(repaired.split(entry)[0]+'\n')
(p/'repair.diff').write_text(''.join(difflib.unified_diff(source.splitlines(True),repaired.splitlines(True),fromfile='upstream/fannkuchredux.ml',tofile='repaired/fannkuchredux.ml')))
(p/'boundary.ml').write_text('''let () =
  Printexc.record_backtrace true;
  let open Kernel_original.Perm in
  let p = setup 3 5 in
  Printf.printf "counter-length=%d zero-first-count=%d\\n" (Array.length p.c) (count p);
  try next p; failwith "expected terminal bounds exception" with
  | Invalid_argument message -> Printf.printf "BOUNDS %s\\n" message; Printexc.print_backtrace stdout
''')
(p/'observer.ml').write_text('''open Kernel_repaired
let () =
  let n = int_of_string Sys.argv.(1) in
  let chunk_size = Perm.facts.(n) / workers and rem = Perm.facts.(n) mod workers in
  let w = Array.init workers (fun _ -> (0,0)) in
  for i = 0 to workers-1 do
    Printf.printf "%d" i;
    let lo = i * chunk_size + min i rem in
    let hi = lo + chunk_size + (if i < rem then 1 else 0) in
    let c,m = fr n lo hi in
    w.(i) <- (c,m);
    Printf.eprintf "CHUNK %d %d %d %d %d\\n" i lo hi c m
  done;
  let c = ref 0 and m = ref 0 in
  Array.iter (fun(nc,nm) -> c := !c+nc; m := max !m nm) w;
  Printf.printf "%d\\nPfannkuchen(%d) = %d\\n" !c n !m
''')
def compile_ocaml(name,files):
    with(p/(name+'-build.log')).open('w')as log:
        subprocess.run(['ocamlopt','-O2','-g','-o',name,*files],cwd=p,check=True,stdout=log,stderr=subprocess.STDOUT)
compile_ocaml('boundary',['kernel_original.ml','boundary.ml'])
compile_ocaml('observer',['kernel_repaired.ml','observer.ml'])
boundary=subprocess.check_output([str(p/'boundary'),'3'],text=True)
assert 'BOUNDS index out of bounds'in boundary and'zero-first-count=1'in boundary
(p/'boundary.txt').write_text(boundary)

managed=Path(os.environ.get('RUNE_HOSTS',str(Path.home()/'.local/rune-hosts')))/'mlton'
if managed.is_dir():managed=managed/'bin/mlton'
assert managed.is_file(),managed
(p/'oracle.sml').write_text('''structure FannkuchReference =
struct
 val n=case TextIO.inputLine TextIO.stdIn of SOME text=>(case Int.fromString text of SOME n=>n |NONE=>raise Fail "n") |NONE=>raise Fail "input"
 val(maximum,checksum)=FannkuchKernel.fannkuch n
 val _=TextIO.output(TextIO.stdOut,Int.toString maximum^" "^Int.toString checksum^"\\n")
end
''')
(p/'oracle.mlb').write_text('$(SML_LIB)/basis/basis.mlb\n'+str(root/'examples/benchmarks/shared/input.sml')+'\n'+str(root/'examples/benchmarks/fannkuch/benchmark.sml')+'\n'+str(p/'oracle.sml')+'\n')
with(p/'oracle-build.log').open('w')as log:
    subprocess.run([str(managed),'-default-type','int64','-default-type','word64','-output',str(p/'oracle'),str(p/'oracle.mlb')],check=True,stdout=log,stderr=subprocess.STDOUT)
meta={'source_sha256':hashlib.sha256(source.encode()).hexdigest(),'repaired_sha256':hashlib.sha256(repaired.encode()).hexdigest(),
      'ocaml_version':subprocess.check_output(['ocamlopt','-version'],text=True).strip(),
      'mlton':str(managed.resolve()),'mlton_options':['-default-type','int64','-default-type','word64'],'profiles':[]}
prefix=''.join(map(str,range(32)))
for profile,n,timeout,memory in [('edge',3,30,1024**3),('smoke',5,30,1024**3),('normal',9,600,4*1024**3),('large',12,3600,8*1024**3)]:
    def limits():
        resource.setrlimit(resource.RLIMIT_AS,(memory,memory));resource.setrlimit(resource.RLIMIT_CORE,(0,0))
    result=subprocess.run([str(p/'observer'),str(n)],capture_output=True,check=True,timeout=timeout,preexec_fn=limits)
    oracle=subprocess.run([str(p/'oracle')],input=(str(n)+'\n').encode(),capture_output=True,check=True,timeout=timeout,preexec_fn=limits)
    maximum,checksum=map(int,oracle.stdout.split())
    expected=(prefix+str(checksum)+'\nPfannkuchen('+str(n)+') = '+str(maximum)+'\n').encode()
    assert result.stdout==expected,(n,result.stdout,expected)
    chunks=[list(map(int,line.split()[1:]))for line in result.stderr.decode().splitlines()]
    assert len(chunks)==32
    cursor=0;running=0;prefixes=[0];partial_bound=0
    for i,lo,hi,c,m in chunks:
        assert lo==cursor and hi>=lo and m<=maximum
        cursor=hi;running+=c;prefixes.append(running);partial_bound=max(partial_bound,(hi-lo)*m)
    assert cursor==__import__('math').factorial(n)and running==checksum
    assert partial_bound<=2**30-1 and all(-2**30<=v<=2**30-1 for v in prefixes)
    (p/(profile+'.expected')).write_bytes(expected);(p/(profile+'.chunks')).write_bytes(result.stderr);(p/(profile+'.oracle')).write_bytes(oracle.stdout)
    meta['profiles'].append({'profile':profile,'n':n,'timeout':timeout,'memory_bytes':memory,'maximum':maximum,'checksum':checksum,'chunk_partial_bound':partial_bound,'global_prefix_range':[min(prefixes),max(prefixes)],'output_sha256':hashlib.sha256(expected).hexdigest()})
    print('PASS repaired checked OCaml and independent managed MLton reference',profile,n,maximum,checksum,flush=True)
(p/'metadata.json').write_text(json.dumps(meta,indent=2)+'\n')
