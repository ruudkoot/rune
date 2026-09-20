(* OS.Path: the tables of https://smlfamily.github.io/Basis/os-path.html
   for getParent, splitDirFile and splitBaseExt, the canonical form, and the
   examples of mkRelative and mkAbsolute. Every line of the .expected file
   is one row of those tables: the 9 of getParent, the 6 of splitDirFile and
   the 8 of splitBaseExt, then the canonical forms, the two examples, the 12
   rows of the mkRelative table, Path for a relativeTo that is not
   absolute, and joinDirFile undoing splitDirFile on the rows of its table. *)
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
fun rel (p, r) = print (p ^ " relative to " ^ r ^ " -> " ^ OS.Path.mkRelative {path = p, relativeTo = r} ^ "\n")
val () = List.app rel [("a/b", "/c/d"), ("/", "/a/b/c"), ("/a/", "/a/b/c"), ("/a/b/", "/a/c"),
                       ("/a/b", "/a/c/"), ("/a/b/", "/a/c/"), ("/", "/"), ("/", "/."), ("/", "/.."),
                       ("/a/b/../c", "/a/d"), ("/a/b", "/c/d"), ("/c/a/b", "/c/d"), ("/c/d/a/b", "/c/d")]
fun path f = (ignore (f ()); "no exception") handle OS.Path.Path => "Path"
val () = print ("mkAbsolute of /a relative to c/d: " ^ path (fn () => OS.Path.mkAbsolute {path = "/a", relativeTo = "c/d"}) ^ "\n")
val () = print ("mkRelative of a relative to c/d: " ^ path (fn () => OS.Path.mkRelative {path = "a", relativeTo = "c/d"}) ^ "\n")
val () = List.app (fn p => print ("join (split " ^ p ^ ") -> " ^ OS.Path.joinDirFile (OS.Path.splitDirFile p) ^ "\n"))
                  ["", ".", "b", "b/", "a/b", "/a", "/"]
