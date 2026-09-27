(* splitBaseExt of paths with an empty arc before the last one *)
fun q s = "\"" ^ s ^ "\""
fun showBE {base, ext} = "{base = " ^ q base ^ ", ext = " ^ (case ext of NONE => "NONE" | SOME e => "SOME " ^ q e) ^ "}"
val () = List.app (fn p => print ("splitBaseExt " ^ q p ^ " = " ^ showBE (OS.Path.splitBaseExt p) ^ "\n"))
                  ["a//c.d", "//c.d", "a/b.c"]
val () = print ("joinBaseExt (splitBaseExt \"a//c.d\") = " ^ q (OS.Path.joinBaseExt (OS.Path.splitBaseExt "a//c.d")) ^ "\n")
