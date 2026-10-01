datatype 'a box = Box of 'a list
datatype tree = Node of tree list
val Box [x,y] = Box [20,22]
val tree = Node [Node [],Node [Node []]]
val _ = if tree = Node [Node [],Node [Node []]] then print (Int.toString (x+y) ^ "\n") else print "bad\n"
val n = let datatype 'a list = Different of 'a
            datatype box = Wrap of int list
            val Wrap (Different k) = Wrap (Different 7)
            val [v] = [k]
        in v end
val _ = print (Int.toString n ^ "\n")
