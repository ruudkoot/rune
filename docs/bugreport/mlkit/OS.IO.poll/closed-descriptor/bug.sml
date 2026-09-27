(* poll of a descriptor that has been closed must raise OS.SysErr. *)
val {infd, outfd} = Posix.IO.pipe ()
val () = (Posix.IO.close infd; Posix.IO.close outfd)
val pd = valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD infd))
val r = (let val l = OS.IO.poll ([OS.IO.pollIn pd], SOME Time.zeroTime)
         in "returned " ^ Int.toString (length l) ^ " poll_info, isIn "
            ^ String.concatWith ", " (map (Bool.toString o OS.IO.isIn) l) end)
        handle OS.SysErr (m, _) => "raised SysErr \"" ^ m ^ "\""
val () = print ("OS.IO.poll of a closed descriptor: " ^ r ^ "\n")
