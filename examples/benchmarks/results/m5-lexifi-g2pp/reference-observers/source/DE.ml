let run limit=
 let trace=ref[]in
 let result=Optimization_source.DE.optimize(Optimization_source.DE.default_parameters 2)
 ~f:(fun x->Array.fold_left(fun h v->h+.v*.v)0. x)
 ~lower_bounds:[|-2.;-2.|]~upper_bounds:[|2.;2.|]
 ~call_back:(fun n value->trace:=(n,value):: !trace)
 ~termination:{Optimization_source.maxit=10000;maxf=limit;target=0.}in
 Printf.printf "limit %d\nresult %.17g %d %s %.17g %.17g\n"limit result.Optimization_source.f result.Optimization_source.nb_feval
 (match result.Optimization_source.status with Optimization_source.Maxit_reached->"iterations"|Optimization_source.Maxf_reached->"evaluations"|Optimization_source.Target_reached->"target")
 result.Optimization_source.x0.(0)result.Optimization_source.x0.(1);
 List.iter(fun(n,v)->Printf.printf "trace %d %.17g\n"n v)(List.rev !trace)
let ()=List.iter run[0;20;40;200]
