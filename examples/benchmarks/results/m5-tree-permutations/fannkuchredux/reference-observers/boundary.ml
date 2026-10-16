let () =
  Printexc.record_backtrace true;
  let open Kernel_original.Perm in
  let p = setup 3 5 in
  Printf.printf "counter-length=%d zero-first-count=%d\n" (Array.length p.c) (count p);
  try next p; failwith "expected terminal bounds exception" with
  | Invalid_argument message -> Printf.printf "BOUNDS %s\n" message; Printexc.print_backtrace stdout
