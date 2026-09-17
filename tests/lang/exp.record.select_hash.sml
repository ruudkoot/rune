val r = {name = "n", age = 3}
val () = print (#name r ^ Int.toString (#age r) ^ "\n")
val getAge = #age : {name : string, age : int} -> int
val () = print (Int.toString (getAge r) ^ Int.toString (#2 (1, 2, 3)) ^ "\n")
val () = print (String.concatWith "," (map #name [{name = "a", age = 1}, {name = "b", age = 2}]) ^ "\n")
