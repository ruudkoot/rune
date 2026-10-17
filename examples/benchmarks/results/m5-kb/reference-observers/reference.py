from pathlib import Path
import shutil,subprocess,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'upstreams/sandmark/benchmarks/kb'
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
records=[]
for name in ['kb','kb_no_exc']:
 d=p/name;d.mkdir(exist_ok=True);shutil.copy(up/(name+'.ml'),d/(name+'.ml'))
 with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','original',name+'.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run([str(d/'original')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=600,preexec_fn=cap,check=True);assert not r.stdout
 (d/'original.stdout').write_bytes(r.stdout);(d/'original.stderr').write_bytes(r.stderr)
 s=(d/(name+'.ml')).read_text();marker='let _ =\n  for i = 1 to 100'
 assert marker in s
 s=s[:s.index(marker)]
 (d/'kernel.ml').write_text(s)
 (d/'observer.ml').write_text("""open Kernel
let rec term = function
 | Var v -> "v" ^ string_of_int v
 | Term(name,sons) -> name ^ "(" ^ String.concat "," (List.map term sons) ^ ")"
let () =
 let n=check_rules [] in
 let eqs=List.map(fun rule->rule.lhs,rule.rhs)geom_rules in
 let result=kb_completion greater n [] [] (n,n) eqs in
 pretty_rules(List.rev result);
 List.iter(fun rule->Printf.printf "%d %d %s=%s\\n" rule.number rule.numvars (term rule.lhs)(term rule.rhs))result
""")
 with(d/'observer-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','kernel.ml','observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
 r=subprocess.run([str(d/'observer')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60,preexec_fn=cap,check=True)
 (p/(name+'.rules')).write_bytes(r.stdout);records.append(dict(variant=name,source_repetitions=100,original_empty_stdout=True,completed_rules=len(r.stdout.splitlines())))
 print(records[-1],flush=True)
assert(p/'kb.rules').read_bytes()==(p/'kb_no_exc.rules').read_bytes()
(p/'metadata.json').write_text(json.dumps(records,indent=2)+'\n')
