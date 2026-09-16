datatype 'a tree = Leaf of 'a | Node of 'a tree * 'a tree
fun sum tree =
  case tree of
    Leaf n => n
  | Node (left, right) => sum left + sum right
val _ = print (Int.toString (sum (Node (Leaf 20, Leaf 22))) ^ "\n")
