datatype tree = Leaf | Node of tree * unit
fun make 0 = Leaf | make n = Node (make (n - 1), ())
val left = make 10000
val right = make 10000
val () = print (Bool.toString (left = right) ^ "\n")
