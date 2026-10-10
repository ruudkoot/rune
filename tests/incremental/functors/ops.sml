(* the operators the others use, and their fixity *)
fun op++ (a, b) = a - b
fun op** (a, b) = a * 10 + b
infix 6 ++
infixr 7 **
