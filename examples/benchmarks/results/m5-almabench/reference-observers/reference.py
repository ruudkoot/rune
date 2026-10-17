from pathlib import Path
import shutil,subprocess,json,resource
p=Path(__file__).resolve().parent;up=p.parent/'upstreams/sandmark/benchmarks/almabench';d=p/'source';shutil.copytree(up,d,dirs_exist_ok=True)
s=(d/'almabench.ml').read_text();(d/'kernel.ml').write_text(s[:s.index('(* Entry point.')])
def cap():resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
with(d/'build.log').open('w')as f:subprocess.run(['ocamlopt','-o','original','almabench.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(d/'original')],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True);assert not r.stdout
(p/'original.stdout').write_bytes(r.stdout);(p/'original.stderr').write_bytes(r.stderr)
(d/'observer.ml').write_text("""open Kernel
let () =
 let mode=Sys.argv.(1) in
 let jd=[|j2000;1.0|] and pv=[|[|0.;0.;0.|];[|0.;0.;0.|]|] and pos=[|0.;0.;0.|] in
 let values()=Array.append(Array.append pv.(0) pv.(1))pos in
 let emit day planet = Printf.printf "%d %d" day planet;Array.iter(fun v->Printf.printf " %.17g" v)(values());print_newline() in
 if mode="points" then
  List.iter(fun day->jd.(0)<-j2000+.float_of_int day;jd.(1)<-0.;
    for planet=0 to 7 do planetpv jd planet pv;radecdist pv pos;emit day planet done)
     [-36525;0;1;2;31;365;12345;36525]
 else begin
  let loops=int_of_string Sys.argv.(2) and days=int_of_string Sys.argv.(3) in
  let sums=Array.make 27 0. in
  let consume()=Array.iteri(fun i v->
    sums.(i)<-sums.(i)+.v;
    sums.(9+i)<-sums.(9+i)+.abs_float v;
    sums.(18+i)<-sums.(18+i)+.v*.v)(values()) in
  for planet=0 to 7 do planetpv jd planet pv;radecdist pv pos;consume() done;
  for _loop=1 to loops do
   jd.(0)<-j2000;jd.(1)<-0.;
   for _day=1 to days do
    jd.(0)<-jd.(0)+.1.;
    for planet=0 to 7 do planetpv jd planet pv;radecdist pv pos;consume() done
   done
  done;
  Array.iter(fun v->Printf.printf "%.17g\\n"v)sums
 end
""")
with(d/'observer-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','observer','kernel.ml','observer.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
r=subprocess.run([str(d/'observer'),'points'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=30,preexec_fn=cap,check=True);(p/'points.reference').write_bytes(r.stdout)
records=[]
for name,loops,days in [('smoke',1,32),('normal',5,36525),('large',20,36525)]:
 r=subprocess.run([str(d/'observer'),'aggregate',str(loops),str(days)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=300,preexec_fn=cap,check=True)
 assert len(r.stdout.splitlines())==27;(p/(name+'.reference')).write_bytes(r.stdout)
 records.append(dict(profile=name,loops=loops,days=days,planet_calls=8+loops*days*8));print(records[-1],flush=True)
(p/'metadata.json').write_text(json.dumps(dict(ocaml=subprocess.check_output(['ocamlopt','-version'],text=True).strip(),unmodified_original_empty_stdout=True,runs=records),indent=2)+'\n')
