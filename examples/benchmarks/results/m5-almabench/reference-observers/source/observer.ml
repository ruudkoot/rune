open Kernel
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
  Array.iter(fun v->Printf.printf "%.17g\n"v)sums
 end
