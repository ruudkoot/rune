(* the labels of a flexible record are determined by the program context,
   possibly in a later declaration, and a generalised flexible record is
   usable at several types *)
fun getX r = #x r
val a = getX {x = 1, y = "one"}
val b = getX {x = "two", y = 2}
fun sel {name, ...} = name
val n1 = sel {name = "n", age = 3}
val n2 = sel {name = 4, age = 3}
fun later r = #value r
val () = print (Int.toString a ^ b ^ n1 ^ Int.toString n2 ^ "\n")
val v = later {value = "v", other = 0.5}
val () = print (v ^ "\n")
