datatype 'a tree = Leaf of 'a | Node of 'a tree * 'a tree | Vacant
val a = Node (Leaf 1,Leaf 2)
val b = Node (Leaf 1,Leaf 3)
fun same x y = x = y
val _ = print (if same a a andalso a <> b andalso Vacant <> a andalso a <> Vacant then "yes\n" else "no\n")
datatype 'a phantom = Phantom
val _ = print (if Phantom = Phantom then "yes\n" else "no\n")
datatype ''a box = Box of ''a
val _ = print (if Box "ok" = Box "ok" then "yes\n" else "no\n")
