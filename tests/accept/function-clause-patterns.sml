datatype 'a tree = Leaf of 'a | Node of 'a tree * 'a tree
fun sum (Leaf n) = n | sum (Node (a,b)) = sum a + sum b
val size = fn (Leaf _, []) => 1 | (Leaf _, xs) => 2 | (Node _, _) => 3
fun sign ~1 = "minus" | sign 0 = "zero" | sign _ = "plus"
val _ = print (Int.toString (sum (Node (Leaf 20,Leaf 22))) ^ "\n")
val _ = print (Int.toString (size (Leaf true,[]) + size (Leaf false,[1]) + size (Node (Leaf 1,Leaf 2),[])) ^ "\n")
val _ = print (sign ~1 ^ "," ^ sign 0 ^ "," ^ sign 2 ^ "\n")
