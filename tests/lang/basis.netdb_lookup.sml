(* NetHostDB, NetProtDB and NetServDB: what every system knows. *)
val () = print ("tcp is " ^ Int.toString (case NetProtDB.getByName "tcp" of
                                            SOME e => NetProtDB.protocol e | NONE => ~1)
                ^ ", udp is " ^ Int.toString (case NetProtDB.getByNumber 17 of
                                                SOME e => NetProtDB.protocol e | NONE => ~1) ^ "\n")
val () = print ("http is port " ^ Int.toString (case NetServDB.getByName ("http", SOME "tcp") of
                                                  SOME e => NetServDB.port e | NONE => ~1)
                ^ ", port 22 is " ^ (case NetServDB.getByPort (22, SOME "tcp") of
                                       SOME e => NetServDB.name e | NONE => "?") ^ "\n")
val () = print ("localhost resolves: "
                ^ Bool.toString (case NetHostDB.getByName "localhost" of
                                   SOME e => NetHostDB.toString (NetHostDB.addr e) = "127.0.0.1" | NONE => false)
                ^ ", hostname is not empty: " ^ Bool.toString (NetHostDB.getHostName () <> "") ^ "\n")
val () = print ("scan: " ^ (case NetHostDB.fromString "10.0.0.1 rest" of
                              SOME a => NetHostDB.toString a | NONE => "none")
                ^ " " ^ (case NetHostDB.fromString "x" of SOME _ => "some" | NONE => "none") ^ "\n")
