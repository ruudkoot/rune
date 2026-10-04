let node name = lazy (print_endline name; 1)
let left = node "left"
let right = node "right"
let () = match Lazy.force left, Lazy.force right with _, _ -> ()
