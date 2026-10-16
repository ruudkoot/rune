open Kernel_repaired
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
    Printf.eprintf "CHUNK %d %d %d %d %d\n" i lo hi c m
  done;
  let c = ref 0 and m = ref 0 in
  Array.iter (fun(nc,nm) -> c := !c+nc; m := max !m nm) w;
  Printf.printf "%d\nPfannkuchen(%d) = %d\n" !c n !m
