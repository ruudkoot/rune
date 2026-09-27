(* concat (p, "") and the arcs of the result *)
fun q s = "\"" ^ s ^ "\""
fun arcs p = "[" ^ String.concatWith ", " (map q (#arcs (OS.Path.fromString p))) ^ "]"
val () = List.app (fn (a, b) => let val c = OS.Path.concat (a, b)
                                in print ("concat (" ^ q a ^ ", " ^ q b ^ ") = " ^ q c ^ ", arcs " ^ arcs c ^ "\n") end)
                  [("a", ""), ("/a", ""), ("a/b", ""), ("a", "b")]
val () = print ("joinDirFile {dir = \"b\", file = \"\"} = " ^ q (OS.Path.joinDirFile {dir = "b", file = ""}) ^ "\n")
