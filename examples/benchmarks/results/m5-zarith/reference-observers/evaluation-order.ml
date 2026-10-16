let visit n = print_int n; n
let add x y = x+y
let tuple x = x
let () = ignore(add (visit 1) (visit 2)); print_newline(); ignore(tuple(visit 1,visit 2,visit 3)); print_newline()
