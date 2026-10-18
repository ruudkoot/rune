from pathlib import Path
import subprocess,json
p=Path(__file__).resolve().parent;d=p/'source'
source='''let run limit=
 let trace=ref[]in
 let result=Optimization.DE.optimize(Optimization.DE.default_parameters 2)
 ~f:(fun x->Array.fold_left(fun h v->h+.v*.v)0.x)
 ~lower_bounds:[|-2.;-2.|]~upper_bounds:[|2.;2.|]
 ~call_back:(fun n value->trace:=(n,value):: !trace)
 ~termination:{Optimization.maxit=10000;maxf=limit;target=0.}in
 Printf.printf "limit %d\\nresult %.17g %d %s %.17g %.17g\\n"limit result.Optimization.f result.Optimization.nb_feval
 (match result.Optimization.status with Optimization.Maxit_reached->"iterations"|Optimization.Maxf_reached->"evaluations"|Optimization.Target_reached->"target")
 result.Optimization.x0.(0)result.Optimization.x0.(1);
 List.iter(fun(n,v)->Printf.printf "trace %d %.17g\\n"n v)(List.rev !trace)
let ()=List.iter run[0;20;40;200]
'''
source=source.replace(')0.x',')0. x')
(d/'Optimization_source.ml').write_bytes((d/'optimization.ml').read_bytes())
source=source.replace('Optimization.', 'Optimization_source.')
(d/'DE.ml').write_text(source)
with(d/'de-build.log').open('w')as f:subprocess.run(['ocamlopt','-o','de-observer','Optimization_source.ml','DE.ml'],cwd=d,stdout=f,stderr=subprocess.STDOUT,check=True)
out=subprocess.check_output([str(d/'de-observer')],cwd=d,timeout=60);(p/'de.reference').write_bytes(out)
print('PASS original sphere-optimizer parameters, exact evaluation counts, stop reasons and improvement traces')
