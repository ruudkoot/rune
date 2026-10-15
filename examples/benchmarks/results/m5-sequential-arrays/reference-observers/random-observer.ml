let () =
 let name = Sys.argv.(1) in
 let state = if name="default" then Random.get_state() else Random.State.make [|int_of_string name|] in
 let mode=Sys.argv.(2) in
 for _ = 1 to 10000 do
  if mode="bits" then Printf.printf "%d\n" (Random.State.bits state)
  else if mode="float" then Printf.printf "%.17g\n" (Random.State.float state 100.0)
  else Printf.printf "%d\n" (Random.State.int state (int_of_string mode))
 done
