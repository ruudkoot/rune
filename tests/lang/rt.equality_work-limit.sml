datatype tree = Leaf | Node of tree * tree
fun make 0 = Leaf
  | make n = let val t = make (n - 1) in Node (t, t) end
val left = make 20
val right = make 20
val () = print (Bool.toString (left = right) ^ "\n")
