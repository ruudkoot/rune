(* OS.Path: the tables of https://smlfamily.github.io/Basis/os-path.html
   for getParent, splitDirFile and splitBaseExt, the canonical form, and the
   examples of mkRelative and mkAbsolute. Every line of the .expected file
   is one row of those tables: the 9 of getParent, the 6 of splitDirFile and
   the 8 of splitBaseExt, then the canonical forms and the two examples. *)
fun show (p, f) = print (p ^ " -> " ^ f p ^ "\n")
val () = List.app (fn p => show (p, OS.Path.getParent)) ["/", "a", "a/", "a///", "a/b", "a/b/", "..", ".", ""]
fun showSplit p = let val {dir, file} = OS.Path.splitDirFile p in print (p ^ " -> {" ^ dir ^ "|" ^ file ^ "}\n") end
val () = List.app showSplit ["", ".", "b", "b/", "a/b", "/a"]
fun showExt p = let val {base, ext} = OS.Path.splitBaseExt p
                in print (p ^ " -> {" ^ base ^ "|" ^ (case ext of NONE => "NONE" | SOME e => e) ^ "}\n") end
val () = List.app showExt ["", ".login", "/.login", "a", "a.", "a.b", "a.b.c", ".news/comp"]
val () = List.app (fn p => show (p, OS.Path.mkCanonical)) ["", "a/../b", "/a/../..", "./a//b/", "../x"]
val () = print (OS.Path.mkRelative {path = "a/b", relativeTo = "/c/d"} ^ " "
                ^ OS.Path.mkRelative {path = "/a/b", relativeTo = "/a/c"} ^ " "
                ^ OS.Path.mkAbsolute {path = "b", relativeTo = "/a"} ^ "\n")
