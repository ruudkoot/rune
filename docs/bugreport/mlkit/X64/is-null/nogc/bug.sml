(* __is_null is the primitive with which MLKit's Basis Library tests
   whether a C function returned NULL; sml_null is the function of MLKit's
   runtime that returns NULL. *)
fun isNull (s : string) : bool = prim ("__is_null", s)
fun null () : string = prim ("sml_null", ())
val () = print ("isNull (null ()) = " ^ Bool.toString (isNull (null ())) ^ "\n")

(* What it does to the Basis Library: ttyname of a descriptor that is not
   a terminal must raise OS.SysErr. *)
val fd = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
val r = (ignore (Posix.ProcEnv.ttyname fd); "returned")
        handle OS.SysErr (m, _) => "raised SysErr \"" ^ m ^ "\""
val () = print ("Posix.ProcEnv.ttyname of /dev/null: " ^ r ^ "\n")
val () = print ("its size: ")
val () = print (Int.toString (size (Posix.ProcEnv.ttyname fd)) ^ "\n")
