(* Windows: what is the same on every system -- the rights of Key as the
   specification makes them up, the codes of Status, and what a status of
   OS.Process is as a code; off Windows a call of the system is SysErr. *)
structure K = Windows.Key
structure S = Windows.Status
fun hex w = "0x" ^ SysWord.toString w
val () = print ("allAccess " ^ hex (K.toWord K.allAccess) ^ " = the six: "
                ^ Bool.toString (K.allAccess = K.flags [K.queryValue, K.enumerateSubKeys, K.notify,
                                                        K.createSubKey, K.createLink, K.setValue]) ^ "\n")
val () = print ("read " ^ hex (K.toWord K.read) ^ " write " ^ hex (K.toWord K.write)
                ^ " execute = read: " ^ Bool.toString (K.execute = K.read) ^ "\n")
val () = print ("accessViolation " ^ hex S.accessViolation ^ " stackOverflow " ^ hex S.stackOverflow
                ^ " controlCExit " ^ hex S.controlCExit ^ "\n")
val () = print ("fromStatus success " ^ hex (Windows.fromStatus OS.Process.success) ^ "\n")
val () = print ("NT is " ^ SysWord.toString Windows.Config.platformWin32NT ^ "\n")
