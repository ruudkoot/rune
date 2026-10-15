module R = Rune_reference_random
let () =
 List.iter (fun (name,s) ->
  Printf.printf "%s\n" name;
  Array.iter (Printf.printf "%d\n") s.R.State.st)
 ["default",R.State.copy R.default;"seed42",R.State.make [|42|];"seed512",R.State.make [|512|]]
