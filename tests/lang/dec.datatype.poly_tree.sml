datatype 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
datatype ('a, 'b) either = Left of 'a | Right of 'b
fun size Leaf = 0 | size (Node (l, _, r)) = size l + 1 + size r
fun map f Leaf = Leaf | map f (Node (l, v, r)) = Node (map f l, f v, map f r)
val t = Node (Node (Leaf, 1, Leaf), 2, Node (Leaf, 3, Leaf))
fun show (Left i) = "L" ^ Int.toString i | show (Right s) = "R" ^ s
val () = print (Int.toString (size (map (fn x => x * 2) t)) ^ show (Left 1) ^ show (Right "x") ^ "\n")
