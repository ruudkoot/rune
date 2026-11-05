(* the operators the files after it read, in the fixity it leaves: <+> a
   constructor and <-> a function made infix, <~> a function left nonfix *)
datatype pair = <+> of int * int
fun <-> (a, b) = a - b
fun <~> (a, b) = a * b
infix 6 <+>
infix 6 <->
