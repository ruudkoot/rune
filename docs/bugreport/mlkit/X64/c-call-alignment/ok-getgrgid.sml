(* The same first look-up through getgrgid, whose C function takes eight
   arguments, two of them on the stack. *)
val () = print "calling Posix.SysDB.getgrgid\n"
val g = (ignore (Posix.SysDB.getgrgid (Posix.ProcEnv.wordToGid 0w0)); "returned")
        handle e => "raised " ^ exnName e
val () = print (g ^ "\n")
