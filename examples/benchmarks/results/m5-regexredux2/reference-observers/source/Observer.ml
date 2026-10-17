let read path = let ic=open_in_bin path in let s=really_input_string ic(in_channel_length ic)in close_in ic;s
let () =
 let mode=Sys.argv.(1) in let pattern=read Sys.argv.(2) in let input=read Sys.argv.(3) in
 if mode="replace" then print_string(Str.global_replace(Str.regexp pattern)(read Sys.argv.(4))input)
 else if mode="count" then begin
  let regex=Str.regexp_case_fold pattern in let i=ref 0 in let count=ref 0 in
  (try while true do i:=1+Str.search_forward regex input !i;incr count done with Not_found->());
  print_endline(string_of_int !count)
 end else begin
  try let start=Str.search_forward(Str.regexp pattern)input 0 in
    Printf.printf "%d %d\n" start(Str.match_end())
  with Not_found->print_endline "none"
 end
